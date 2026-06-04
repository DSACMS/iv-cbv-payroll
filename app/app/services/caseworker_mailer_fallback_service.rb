class CaseworkerMailerFallbackService
  FALLBACK_EMAIL_MISSING = "(no fallback email configured)".freeze
  FILTERS = {
    "la_ldh_schema_error" => "API Specification validation failed"
  }.freeze

  def preview(filter_name: nil)
    entries = failed_caseworker_executions(filter_name: filter_name).map { |failed_execution| entry_for(failed_execution) }

    { count: entries.count, entries: entries }
  end

  def deliver_all(filter_name: nil)
    sent = 0
    skipped = []

    failed_caseworker_executions(filter_name: filter_name).each do |failed_execution|
      entry = entry_for(failed_execution)
      unless entry[:status] == :sendable
        skipped << skip_message(entry)
        next
      end

      deliver(entry)
      entry[:cbv_flow].touch(:transmitted_at)
      failed_execution.destroy

      sent += 1
    end

    { sent: sent, skipped: skipped }
  end

  private

  def failed_caseworker_executions(filter_name:)
    scope = SolidQueue::FailedExecution
      .joins(:job)
      .where(solid_queue_jobs: { class_name: "CaseWorkerTransmitterJob" })
      .includes(:job)

    return scope if filter_name.blank?

    filter_value = FILTERS.fetch(filter_name) do
      raise ArgumentError, "Unknown caseworker mailer fallback filter: #{filter_name}"
    end

    case filter_name
    when "la_ldh_schema_error"
      scope.where("solid_queue_failed_executions.error LIKE ?", "%#{filter_value}%")
    end
  end

  def entry_for(failed_execution)
    cbv_flow_id = cbv_flow_id_from(failed_execution)
    cbv_flow = CbvFlow.find_by(id: cbv_flow_id)

    return skipped_entry(failed_execution, cbv_flow_id, "CbvFlow record not found") unless cbv_flow

    agency = Rails.application.config.client_agencies[cbv_flow.cbv_applicant.client_agency_id]
    base_entry = {
      failed_execution: failed_execution,
      cbv_flow: cbv_flow,
      cbv_flow_id: cbv_flow.id,
      agency_id: agency&.id,
      fallback_email: agency&.caseworker_fallback_email || FALLBACK_EMAIL_MISSING,
      case_number: cbv_flow.cbv_applicant.case_number,
      transmitted: transmitted_status(cbv_flow),
      error: failed_execution.error
    }

    if cbv_flow.transmitted_at?
      base_entry.merge(status: :skipped, reason: "already transmitted at #{cbv_flow.transmitted_at}")
    elsif cbv_flow.cbv_applicant.redacted_at?
      base_entry.merge(status: :skipped, reason: "applicant is redacted")
    elsif agency&.caseworker_fallback_email.blank?
      base_entry.merge(status: :skipped, reason: "no caseworker_fallback_email configured for agency #{agency&.id || 'unknown'}")
    else
      base_entry.merge(status: :sendable)
    end
  rescue => e
    {
      failed_execution: failed_execution,
      solid_queue_job_id: failed_execution.job_id,
      status: :error,
      reason: "Error reading job: #{e.message}",
      error: failed_execution.error
    }
  end

  def cbv_flow_id_from(failed_execution)
    failed_execution.job.arguments["arguments"][0]
  end

  def skipped_entry(failed_execution, cbv_flow_id, reason)
    {
      failed_execution: failed_execution,
      cbv_flow_id: cbv_flow_id,
      status: :skipped,
      reason: reason,
      error: failed_execution.error
    }
  end

  def transmitted_status(cbv_flow)
    if cbv_flow.transmitted_at?
      "already sent at #{cbv_flow.transmitted_at}"
    else
      "not yet sent"
    end
  end

  def skip_message(entry)
    if entry[:cbv_flow_id]
      "cbv_flow_id=#{entry[:cbv_flow_id]}: #{entry[:reason]}"
    else
      "solid_queue_job_id=#{entry[:solid_queue_job_id]}: #{entry[:reason]}"
    end
  end

  def deliver(entry)
    aggregator_report = AggregatorReportFetcher.new(entry[:cbv_flow]).report
    CaseworkerMailer.with(
      email_address: entry[:fallback_email],
      cbv_flow: entry[:cbv_flow],
      aggregator_report: aggregator_report
    ).summary_email.deliver_now

    Rails.logger.info "[CaseworkerMailerFallback] Sent fallback email cbv_flow_id=#{entry[:cbv_flow_id]} agency=#{entry[:agency_id]} to=#{entry[:fallback_email]}"
  end
end
