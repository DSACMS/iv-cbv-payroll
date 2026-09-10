class Launcher::NscForwardDatingService
  LAUNCHER_SCENARIO_KEYS = %w[lynette rick dominique scott linda].freeze
  # These dates match each persona's latest term end so NSC reports them as currently enrolled before forward-dating.
  LAUNCHER_AS_OF_DATES = {
    "lynette" => Date.new(2024, 11, 19),
    "rick" => Date.new(2024, 11, 29),
    "dominique" => Date.new(2024, 5, 9)
  }.freeze

  def self.applicable?(education_activity)
    scenario_key = scenario_key_for(education_activity)
    scenario_key.present? && LAUNCHER_SCENARIO_KEYS.include?(scenario_key)
  end

  def self.scenario_key_for(education_activity)
    education_activity.activity_flow.activity_flow_invitation&.reference_id&.delete_prefix("demo-")
  end

  def initialize(education_activity:, logger: Rails.logger, environment: ENV.fetch("NSC_ENVIRONMENT", "sandbox"))
    @education_activity = education_activity
    @data_fetcher_service = NscDataFetcherService.new(
      education_activity: education_activity,
      logger: logger,
      environment: environment,
      response_transformer: method(:forward_dated_response),
      as_of_date: launcher_as_of_date
    )
  end

  def fetch
    @data_fetcher_service.fetch
  end

  private

  def launcher_as_of_date
    LAUNCHER_AS_OF_DATES[self.class.scenario_key_for(@education_activity)]
  end

  def forward_dated_response(response)
    anchor_term_end = anchor_term_end_for(response)
    return response unless anchor_term_end

    delta_days = (@education_activity.activity_flow.reporting_window_range.max - anchor_term_end).to_i
    transformed_response = response.deep_dup

    Array(transformed_response["enrollmentDetails"]).each do |detail|
      Array(detail["enrollmentData"]).each do |term|
        term["termBeginDate"] = shift_date_string(term["termBeginDate"], delta_days)
        term["termEndDate"] = shift_date_string(term["termEndDate"], delta_days)
      end
    end

    transformed_response
  end

  def anchor_term_end_for(response)
    term_ends = Array(response["enrollmentDetails"])
      .flat_map { |detail| Array(detail["enrollmentData"]) }
      .filter_map { |term| term["termEndDate"].presence && Date.parse(term["termEndDate"]) }
    return if term_ends.empty?

    as_of_date = launcher_as_of_date
    return term_ends.max if as_of_date.blank?

    term_ends.select { |term_end| term_end <= as_of_date }.max || term_ends.max
  end

  def shift_date_string(date_str, delta_days)
    return date_str if date_str.blank?

    (Date.parse(date_str) + delta_days).strftime("%Y-%m-%d")
  end
end
