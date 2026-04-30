class DemoLauncher::FakeNscDataFetcherService < NscDataFetcherService
  def initialize(education_activity:, logger: Rails.logger)
    @education_activity = education_activity
    @logger = logger
  end

  def fetch
    response = fake_nsc_response_for

    update_education_activity(@education_activity, response)

    if @education_activity.sync_succeeded?
      save_enrollment_terms(Array(response["enrollmentDetails"]))
      @education_activity.update!(
        data_source: EducationActivity.data_source_from_nsc_results(
          @education_activity.nsc_enrollment_terms,
          reporting_months: @education_activity.activity_flow.reporting_months
        )
      )
    end
  end

  private

  def fake_nsc_response_for
    DemoLauncher::FakeNscScenarios.nsc_response_for(
      identity: @education_activity.activity_flow.identity,
      reporting_window: @education_activity.activity_flow.reporting_window_range
    ) || { "enrollmentDetails" => [] }
  end
end
