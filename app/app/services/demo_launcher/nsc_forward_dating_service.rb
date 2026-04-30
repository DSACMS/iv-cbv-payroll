class DemoLauncher::NscForwardDatingService
  def self.applicable?(education_activity)
    scenario_key = education_activity.activity_flow.activity_flow_invitation&.reference_id&.delete_prefix("demo-")
    scenario_key.present? && DemoLauncherController::TEST_SCENARIOS.key?(scenario_key)
  end

  def initialize(education_activity:, logger: Rails.logger, environment: ENV.fetch("NSC_ENVIRONMENT", "sandbox"))
    @education_activity = education_activity
    @data_fetcher_service = NscDataFetcherService.new(
      education_activity: education_activity,
      logger: logger,
      environment: environment,
      response_transformer: method(:forward_dated_response)
    )
  end

  def fetch
    @data_fetcher_service.fetch
  end

  private

  def forward_dated_response(response)
    latest_term_end = Array(response["enrollmentDetails"])
      .flat_map { |detail| Array(detail["enrollmentData"]) }
      .filter_map { |term| term["termEndDate"].presence && Date.parse(term["termEndDate"]) }
      .max
    return response unless latest_term_end

    delta_days = (@education_activity.activity_flow.reporting_window_range.max - latest_term_end).to_i
    transformed_response = response.deep_dup

    Array(transformed_response["enrollmentDetails"]).each do |detail|
      Array(detail["enrollmentData"]).each do |term|
        term["termBeginDate"] = shift_date_string(term["termBeginDate"], delta_days)
        term["termEndDate"] = shift_date_string(term["termEndDate"], delta_days)
      end
    end

    transformed_response
  end

  def shift_date_string(date_str, delta_days)
    return date_str if date_str.blank?

    (Date.parse(date_str) + delta_days).strftime("%Y-%m-%d")
  end
end
