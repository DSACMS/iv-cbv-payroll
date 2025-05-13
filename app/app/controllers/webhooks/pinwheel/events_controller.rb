class Webhooks::Pinwheel::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_pinwheel, :authorize_webhook
  after_action :process_webhook_event
  skip_before_action :verify_authenticity_token

  # To prevent timing attacks, we attempt to verify the webhook signature
  # using a same-length dummy key even if the `end_user_id` does not match a
  # valid `cbv_flow`.
  DUMMY_API_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  def create
    @payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(type: :pinwheel, pinwheel_account_id: params["payload"]["account_id"]) do |new_payroll_account|
      new_payroll_account.supported_jobs = get_supported_jobs(params["payload"]["platform_id"])
    end

    @webhook_event = WebhookEvent.create!(
      payroll_account: @payroll_account,
      event_name: params["event"],
      event_outcome: params.dig("payload", "outcome"),
    )
  end

  private

  def authorize_webhook
    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    digest = @pinwheel.generate_signature_digest(timestamp, request.raw_post)
    unless @pinwheel.verify_signature(signature, digest)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def set_cbv_flow
    @cbv_flow = CbvFlow.find_by_end_user_id(params["payload"]["end_user_id"])

    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow for end_user_id: #{params["payload"]["end_user_id"]}"
      render json: { status: "ok" }
    end
  end

  def set_pinwheel
    @pinwheel = @cbv_flow.present? ? pinwheel_for(@cbv_flow) : Aggregators::Sdk::PinwheelService.new("sandbox", DUMMY_API_KEY)
  end

  def get_supported_jobs(platform_id)
    @pinwheel.fetch_platform(platform_id: platform_id)["data"]["supported_jobs"]
  end

  def process_webhook_event
    if @webhook_event.event_name == "account.added"
      event_logger.track("ApplicantCreatedPinwheelAccount", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        client_agency_id: @cbv_flow.client_agency_id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        platform_name: params["payload"]["platform_name"]
      })
    elsif @payroll_account.has_fully_synced?
      report = Aggregators::AggregatorReports::PinwheelReport.new(
        payroll_accounts: [ @payroll_account ],
        pinwheel_service: @pinwheel,
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date
      )
      report.fetch

      if @payroll_account.necessary_jobs_succeeded? && validate_useful_report_requirements(report)
        @payroll_account.update(synchronization_status: :succeeded)
      else
        @payroll_account.update(synchronization_status: :failed)
      end

      event_logger.track("ApplicantFinishedPinwheelSync", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        client_agency_id: @cbv_flow.client_agency_id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        pinwheel_environment: agency_config[@cbv_flow.client_agency_id].pinwheel_environment,
        sync_duration_seconds: Time.now - @payroll_account.created_at,

        # #####################################################################
        # Add attributes to track provider data quality.
        #
        # **Important Note**: We do not send PII to our analytics platforms!
        # As such, any field here that deals with PII should coerce it into a
        # boolean (with `#present?`) or perform a function to anonymize the
        # value (like `length`) before sending it to the event logger.
        # #####################################################################

        # Identity fields
        identity_success: @payroll_account.job_succeeded?("identity"),
        identity_supported: @payroll_account.supported_jobs.include?("identity"),
        identity_count: report.identities.length,
        identity_full_name_present: report.identities.first&.full_name&.present?,
        identity_full_name_length: report.identities.first&.full_name&.length,
        identity_date_of_birth_present: report.identities.first&.date_of_birth.present?,
        identity_ssn_present: report.identities.first&.ssn.present?,
        identity_emails_count: report.identities.sum { |i| i.emails.length },
        identity_phone_numbers_count: report.identities.sum { |i| i.phone_numbers.length },

        # Income fields
        income_success: @payroll_account.job_succeeded?("income"),
        income_supported: @payroll_account.supported_jobs.include?("income"),
        income_compensation_amount_present: report.incomes.first&.compensation_amount.present?,
        income_compensation_unit_present: report.incomes.first&.compensation_unit.present?,
        income_pay_frequency_present: report.incomes.first&.pay_frequency.present?,

        # Paystubs fields
        paystubs_success: @payroll_account.job_succeeded?("paystubs"),
        paystubs_supported: @payroll_account.supported_jobs.include?("paystubs"),
        paystubs_count: report.paystubs.length,
        paystubs_deductions_count: report.paystubs.sum { |p| p.deductions.length },
        paystubs_hours_by_earning_category_count: report.paystubs.sum { |p| p.hours_by_earning_category.length },
        paystubs_hours_present: report.paystubs.first&.hours.present?,
        paystubs_earnings_count: report.paystubs.sum { |p| p.earnings.length },
        paystubs_earnings_with_hours_count: report.paystubs.sum { |p| p.earnings.count { |e| e.hours.present? } },
        paystubs_earnings_category_salary_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "salary" } },
        paystubs_earnings_category_bonus_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "bonus" } },
        paystubs_earnings_category_overtime_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "overtime" } },
        paystubs_days_since_last_paid: report.paystubs.map { |p| Date.parse(p.pay_date) }.compact.max&.then { |last_pay_date| (Date.current - last_pay_date).to_i },

        # Employment fields
        employment_success: @payroll_account.job_succeeded?("employment"),
        employment_supported: @payroll_account.supported_jobs.include?("employment"),
        employment_status: report.employments.first&.status,
        employment_employer_name: report.employments.first&.employer_name,
        employment_employer_address_present: report.employments.first&.employer_address&.present?,
        employment_employer_phone_number_present: report.employments.first&.employer_name&.present?,
        employment_start_date: report.employments.first&.start_date,
        employment_termination_date: report.employments.first&.termination_date,
        employment_type: report.employments.first&.employment_type&.to_s,
        employment_type_w2_count: report.employments.count { |e| e.employment_type == :w2 },
        employment_type_gig_count: report.employments.count { |e| e.employment_type == :gig },

        # Shifts fields
        gigs_success: @payroll_account.job_succeeded?("shifts"),
        gigs_supported: @payroll_account.supported_jobs.include?("shifts"),
        gigs_count: report.gigs.length,
        gigs_pay_present_count: report.gigs.count { |g| g.compensation_amount.present? },
        gigs_start_date_present_count: report.gigs.count { |g| g.start_date.present? },
        gigs_type_delivery_count: report.gigs.count { |g| g.gig_type == "delivery" },
        gigs_type_other_count: report.gigs.count { |g| g.gig_type == "other" },
        gigs_type_rideshare_count: report.gigs.count { |g| g.gig_type == "rideshare" },
        gigs_type_shift_count: report.gigs.count { |g| g.gig_type == "shift" }
      })
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to track NewRelic event (in #{self.class.name}): #{ex}"
  end

  def validate_useful_report_requirements(report)
    report_is_valid = report.valid?(:useful_report)
    if report_is_valid
      event_logger.track("ApplicantReportMetUsefulRequirements", request,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id
      )
    else
      event_logger.track("ApplicantReportFailedUsefulRequirements", request,
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        errors: report.errors.full_messages.join(", ")
      )
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to track event (in #{self.class.name}): #{ex}"
  ensure
    return report_is_valid
  end
end
