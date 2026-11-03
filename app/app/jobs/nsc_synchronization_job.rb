# Synchronizes data from the National Student Clearinghouse (NSC)
class NscSynchronizationJob < ApplicationJob
  include Trackable

  queue_as :default

  after_discard do |job, exception|
    education_activity = EducationActivity.find(job.arguments.first)
    Rails.logger.error("Failed #{self.class.name} for EducationActivity ID #{education_activity.id}")
    education_activity.update(status: :failed)
  end

  def perform(education_activity_id)
    @lookup_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Rails.logger.info "Fetching NSC Data for EducationActivity #{education_activity_id}"

    @education_activity = EducationActivity.find(education_activity_id)
    unless @education_activity.sync_unknown?
      Rails.logger.warn "Duplicate #{self.class.name} enqueued for already-fetched EducationActivity ID #{@education_activity.id}"
    end

    data_fetcher_service.fetch
    @education_activity.reload
    track_lookup_result unless @education_activity.sync_unknown?
  rescue StandardError
    track_lookup_result(outcome: "service_error") if @education_activity
    raise
  end

  private

  # Background lookups have no HTTP request; supply the same CE identifiers
  # explicitly so the shared tracker can associate the result with the journey.
  def request
    nil
  end

  def standard_track_attributes
    flow = @education_activity.activity_flow
    {
      flow_type: "ce",
      cbv_flow_id: flow.id,
      cbv_applicant_id: flow.cbv_applicant_id,
      invitation_id: flow.invitation_id,
      client_agency_id: flow.cbv_applicant.client_agency_id,
      device_id: flow.device_id,
      education_activity_id: @education_activity.id,
      education_flow: "nsc",
      education_data_source: @education_activity.sync_unknown? ? "pending" : @education_activity.data_source,
      education_type: @education_activity.education_type
    }
  end

  def track_lookup_result(outcome: nil)
    terms = @education_activity.nsc_enrollment_terms.to_a
    months = EducationReportingMonthResolver.new(
      terms: terms, reporting_months: @education_activity.activity_flow.reporting_months
    ).reporting_month_enrollments
    outcome ||= if @education_activity.sync_no_enrollments?
                  "no_enrollments"
                elsif @education_activity.sync_failed?
                  "service_error"
                elsif @education_activity.partially_self_attested?
                  "partial_data"
                else
                  "validated"
                end

    track_event(TrackEvent::EducationNscLookupCompleted,
      outcome: outcome,
      lookup_attempt: executions,
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @lookup_started_at) * 1000).round,
      nsc_status: @education_activity.status,
      term_count: terms.size,
      enrollment_status_counts: terms.map(&:enrollment_status).tally,
      reporting_month_count: months.size,
      months_with_enrollment: months.count { |month| month.terms.any? || month.effective_term.present? },
      months_with_sufficient_enrollment: months.count(&:sufficient_enrollment?))
  rescue StandardError => error
    # Instrumentation must not turn a completed lookup into another NSC request.
    Rails.logger.warn("Unable to track NSC lookup for EducationActivity #{@education_activity.id}: #{error.class.name}")
  end

  def data_fetcher_service
    if use_launcher_fake_data_fetcher?
      Launcher::FakeNscDataFetcherService.new(education_activity: @education_activity)
    elsif use_launcher_forward_dating_service?
      Launcher::NscForwardDatingService.new(education_activity: @education_activity)
    else
      NscDataFetcherService.new(education_activity: @education_activity)
    end
  end

  def use_launcher_fake_data_fetcher?
    return false unless Rails.application.config.is_internal_environment

    Launcher::FakeNscScenarios.by_identity(@education_activity.activity_flow.identity).present?
  end

  def use_launcher_forward_dating_service?
    return false unless Rails.application.config.is_internal_environment

    Launcher::NscForwardDatingService.applicable?(@education_activity)
  end
end
