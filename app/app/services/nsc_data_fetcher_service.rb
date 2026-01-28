class NscDataFetcherService
  CURRENTLY_ENROLLED = "CC"
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

    if @education_activity.sync_succeeded?
      save_enrollment_terms(response["enrollmentDetails"])
    end
  end

  private

  def update_education_activity(education_activity, response_data)
    enrollments = Array(response_data["enrollmentDetails"])
    current_enrollments = enrollments.find_all { |enrollment_detail| enrollment_detail["currentEnrollmentStatus"] == "CC" }

    if current_enrollments.any?
      @logger.info "Found #{current_enrollments.length} current enrollments (total enrollments: #{enrollments.length})"
      @education_activity.update(status: :succeeded)
    else
      @logger.info("No enrollments found for EducationActivity ID #{education_activity.id}")
      @education_activity.update(status: :no_enrollments)
    end
  end

  def save_enrollment_terms(enrollment_details)
    enrollment_details.each do |enrollment_detail|
      next unless enrollment_detail["currentEnrollmentStatus"] == CURRENTLY_ENROLLED

      enrollment_detail["enrollmentData"].each do |enrollment_data|
        @education_activity.nsc_enrollment_terms.create!(
          school_name: enrollment_detail["officialSchoolName"],
          first_name: enrollment_detail["nameOnSchoolRecord"]["firstName"],
          middle_name: enrollment_detail["nameOnSchoolRecord"]["middleName"],
          last_name: enrollment_detail["nameOnSchoolRecord"]["lastName"],

          enrollment_status: enrollment_status(enrollment_data),
          term_begin: enrollment_data["termBeginDate"],
          term_end: enrollment_data["termEndDate"],
        )
      end
    end
  end

  private

  def enrollment_status(enrollment_data)
    ENROLLMENT_STATUSES.fetch(enrollment_data["enrollmentStatus"]) do
      @logger.error "Unknown enrollmentStatus (add to ENROLLMENT_STATUSES): #{enrollment_data["enrollmentStatus"]}"

      "unknown"
    end
  end
end
