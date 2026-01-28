class NscDataFetcherService
  ENROLLMENT_STATUSES = {
    # Ordered in descending preference if there are multiple active enrollments.
    # The key is the API response value
    # The value is the enum value for EducationActivity.
    "F" => :full_time,
    "Q" => :three_quarter_time,
    "H" => :half_time,
    "L" => :less_than_half_time,
    "Y" => :enrolled
  }

  def initialize(education_activity:, logger: Rails.logger, environment: ENV.fetch("NSC_ENVIRONMENT", "sandbox"))
    @education_activity = education_activity
    @logger = logger
    @service = Aggregators::Sdk::NscService.new(environment: environment, logger: logger)
  end

  # Main entry pont to submit an enrollment request to NSC
  def fetch
    identity = @education_activity.activity_flow.identity
    response = @service.fetch_enrollment_data(
      first_name: identity.first_name,
      last_name: identity.last_name,
      date_of_birth: identity.date_of_birth,
      as_of_date: @education_activity.activity_flow.reporting_window_range.max
    )

    update_education_activity(@education_activity, response)
  end

  private

  def update_education_activity(education_activity, response_data)
    enrollments = Array(response_data["enrollmentDetails"])
    current_enrollments = enrollments.find_all { |enrollment_detail| enrollment_detail["currentEnrollmentStatus"] == "CC" }

    if current_enrollments.any?
      @logger.info "Found #{current_enrollments.length} current enrollments (total enrollments: #{enrollments.length})"
    else
      @logger.info("No enrollments found for EducationActivity ID #{education_activity.id}")
      return education_activity.update(status: :no_enrollments)
    end

    # Of potentially multiple current enrollments, pick the one with:
    # - The highest enrollment status (i.e. prefer "full time" to "half time")
    # - The latest termEndDate
    current_enrollment_terms = current_enrollments.each_with_object([]) do |enrollment_detail, array|
      enrollment_detail["enrollmentData"].each do |enrollment_data|
        array << {
          school_name: enrollment_detail["officialSchoolName"],
          enrollment_status: enrollment_data["enrollmentStatus"],
          term_end_date: enrollment_data["termEndDate"]
        }
      end
    end
    latest_current_enrollment_term = current_enrollment_terms
      .sort_by { |e| [ ENROLLMENT_STATUSES.values.index(e[:enrollment_status]), e[:term_end_date] ] }
      .first

    education_activity.update(
      school_name: latest_current_enrollment_term[:school_name],
      enrollment_status: ENROLLMENT_STATUSES.fetch(latest_current_enrollment_term[:enrollment_status], "unknown"),
      status: :succeeded
    )
  end
end
