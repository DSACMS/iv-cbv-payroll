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
    response = shift_enrollment_dates_for_demo(response)

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
    activity_flow = @education_activity.activity_flow

    enrollment_details.each do |enrollment_detail|
      next unless enrollment_detail["currentEnrollmentStatus"] == CURRENTLY_ENROLLED

      enrollment_detail["enrollmentData"].each do |enrollment_data|
        term_begin = Date.parse(enrollment_data["termBeginDate"])
        term_end = Date.parse(enrollment_data["termEndDate"])
        next unless activity_flow.within_reporting_window?(term_begin, term_end)

        @education_activity.nsc_enrollment_terms.create!(
          school_name: enrollment_detail["officialSchoolName"],
          first_name: enrollment_detail["nameOnSchoolRecord"]["firstName"],
          middle_name: enrollment_detail["nameOnSchoolRecord"]["middleName"],
          last_name: enrollment_detail["nameOnSchoolRecord"]["lastName"],
          enrollment_status: enrollment_status(enrollment_data),
          term_begin: term_begin,
          term_end: term_end,
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

  # In demo and development environments, shift enrollment term dates for
  # currently-enrolled (CC) students so they overlap with a recent reporting
  # window. This is necessary because NSC sandbox test data has dates from
  # 1+ years ago, which would never overlap with a real reporting window.
  #
  # The shift targets the 15th of the previous month so the terms overlap
  # with both 1-month (application) and 6-month (renewal) reporting windows.
  def shift_enrollment_dates_for_demo(response_body)
    return response_body unless Rails.application.config.is_internal_environment

    enrollments = Array(response_body["enrollmentDetails"])
    cc_enrollments = enrollments.select { |ed| ed["currentEnrollmentStatus"] == CURRENTLY_ENROLLED }
    return response_body if cc_enrollments.empty?

    max_term_end = cc_enrollments
      .flat_map { |ed| ed["enrollmentData"] || [] }
      .filter_map { |term| Date.parse(term["termEndDate"]) rescue nil }
      .max

    return response_body if max_term_end.nil?

    target_date = Date.today.beginning_of_month - 15.days
    offset_days = (target_date - max_term_end).to_i

    return response_body if offset_days == 0

    @logger.info("Demo mode: shifting CC enrollment dates by #{offset_days} days")

    cc_enrollments.each do |enrollment_detail|
      (enrollment_detail["enrollmentData"] || []).each do |term|
        %w[termBeginDate termEndDate].each do |date_field|
          next unless term[date_field].present?

          original_date = Date.parse(term[date_field])
          term[date_field] = (original_date + offset_days.days).iso8601
        end
      end
    end

    response_body
  end
end
