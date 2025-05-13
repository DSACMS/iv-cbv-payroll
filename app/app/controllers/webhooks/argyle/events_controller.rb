class Webhooks::Argyle::EventsController < ApplicationController
  before_action :set_cbv_flow, :authorize_webhook
  skip_before_action :verify_authenticity_token

  def create
    case params["event"]
    when "users.fully_synced"
      # Handle the users.fully_synced event with potentially multiple accounts.
      # If users add more than one account then this array will contain the IDs
      # of all the accounts that were connected. This method iterates over the
      # account IDs and creates webhook events for any accounts that don't yet
      # have a "users.fully_synced" event.
      handle_users_fully_synced.each do |webhook_event|
        process_webhook_event(webhook_event)
      end
    else
      # All other webhooks have a params["data"]["account"], which we can use
      # to find the account.
      account_id = params.dig("data", "account")
      payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(type: :argyle, pinwheel_account_id: account_id) do |new_payroll_account|
        new_payroll_account.synchronization_status = :in_progress
        new_payroll_account.supported_jobs = Aggregators::Webhooks::Argyle.get_supported_jobs
      end

      webhook_event = create_webhook_event_for_account(params["event"], payroll_account)
      update_synchronization_page(payroll_account)
      log_data_sync_events(payroll_account, params)
      process_webhook_event(webhook_event)
    end

    render json: { status: "ok" }
  end

  private

  def handle_users_fully_synced
    accounts_connected = params.dig("data", "resource", "accounts_connected")
    raise "No accounts_connected in users.fully_synced webhook" unless accounts_connected.present?

    # Get the payroll accounts that do not have a webhook event for "users.fully_synced"
    # rather than iterating over each account entry that Argyle sends back.
    #
    # In the event that a user adds multiple payroll accounts we do not want to
    # record duplicate webhook events
    syncing_payroll_accounts = PayrollAccount::Argyle
      .awaiting_fully_synced_webhook
      .where(cbv_flow: @cbv_flow)

    # Handle each connected account separately
    syncing_payroll_accounts.map do |payroll_account|
      webhook_event = create_webhook_event_for_account(params["event"], payroll_account)
      update_synchronization_page(payroll_account)
      log_data_sync_events(payroll_account, params)
      webhook_event
    end
  end

  def create_webhook_event_for_account(event_name, payroll_account)
    WebhookEvent.create!(
      payroll_account: payroll_account,
      event_name: event_name,
      event_outcome: Aggregators::Webhooks::Argyle.get_webhook_event_outcome(event_name)
    )
  end

  def set_cbv_flow
    user_id = params.dig("data", "user")
    @cbv_flow = CbvFlow.find_by(argyle_user_id: user_id)

    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow with argyle_user_id: #{user_id}"
      render json: { status: "ok" }
    end
  end

  # @see https://docs.argyle.com/api-guide/webhooks
  def authorize_webhook
    argyle_service = @cbv_flow.present? ? argyle_for(@cbv_flow) : ArgyleService.new("sandbox")

    unless Aggregators::Webhooks::Argyle.get_webhook_events(type: :all).include?(params["event"])
      Rails.logger.info "Ignoring unhandled webhook: #{params["event"]}"
      render json: { info: "Unhandled webhook" }, status: :ok
    end

    unless Aggregators::Webhooks::Argyle.verify_signature(request.headers["X-Argyle-Signature"], request.raw_post, argyle_service.webhook_secret)
      Rails.logger.info "Ignoring webhook with invalid signature: #{params["event"]}"
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def process_accounts_updated_event(webhook_event)
    payroll_account = webhook_event.payroll_account
    connection_status = params.dig("data", "resource", "connection", "status")
    error_code = params.dig("data", "resource", "connection", "error_code")
    return unless connection_status == "error" && error_code == "system_error"

    event_logger.track("ApplicantEncounteredArgyleAccountSystemError", request, {
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      connection_status: connection_status,
      argyle_error_code: error_code,
      argyle_error_message: params.dig("data", "resource", "connection", "error_message"),
      argyle_error_updated_at: params.dig("data", "resource", "connection", "updated_at")
    })

    webhook_event.update(event_outcome: "error")
    payroll_account.update(synchronization_status: :failed)
    update_synchronization_page(payroll_account)
  end

  def process_webhook_event(webhook_event)
    payroll_account = webhook_event.payroll_account

    if webhook_event.event_name == "accounts.connected"
      event_logger.track("ApplicantCreatedArgyleAccount", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        provider_name: params.dig("data", "resource", "providers_connected")&.first
      })
    elsif webhook_event.event_name == "accounts.updated"
      process_accounts_updated_event(webhook_event)
    elsif payroll_account.has_fully_synced?
      return if payroll_account.sync_succeeded? || payroll_account.sync_failed?

      report = Aggregators::AggregatorReports::ArgyleReport.new(
        payroll_accounts: [ payroll_account ],
        argyle_service: argyle_for(@cbv_flow),
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date
      )
      report.fetch

      log_sync_finish(payroll_account, report)

      if payroll_account.necessary_jobs_succeeded? && validate_useful_report_requirements(report)
        payroll_account.update(synchronization_status: :succeeded)
      else
        payroll_account.update(synchronization_status: :failed)
      end
    end
  end

  # For analytics during testing (and maybe for the pilots as well) we want to
  # measure the time it takes for real users at extra time intervals.
  def log_data_sync_events(payroll_account, params)
    if params["event"] == "paystubs.partially_synced" || params["event"] == "gigs.partially_synced"
      days_synced = params["data"]["days_synced"].to_i
      sync_data = if days_synced < 182
                    :ninety_days
                  else
                    :six_months
                  end

      event_logger.track("ApplicantReceivedArgyleData", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        sync_data: sync_data.to_s,
        sync_duration_seconds: Time.now - payroll_account.sync_started_at,
        sync_event: params["event"]
      })
    elsif params["event"] == "users.fully_synced"
      event_logger.track("ApplicantReceivedArgyleData", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        sync_data: "fully_synced",
        sync_duration_seconds: Time.now - payroll_account.sync_started_at,
        sync_event: params["event"]
      })
    end
  end

  def log_sync_finish(payroll_account, report)
    begin
      paystub_hours = report.paystubs.filter_map(&:hours).map(&:to_f)
      paystub_gross_pay_amounts = report.paystubs.filter_map(&:gross_pay_amount)

      event_logger.track("ApplicantFinishedArgyleSync", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        argyle_environment: agency_config[@cbv_flow.client_agency_id].argyle_environment,
        sync_duration_seconds: Time.now - payroll_account.sync_started_at,

        # #####################################################################
        # Add attributes to track provider data quality.
        #
        # **Important Note**: We do not send PII to our analytics platforms!
        # As such, any field here that deals with PII should coerce it into a
        # boolean (with `#present?`) or perform a function to anonymize the
        # value (like `length`) before sending it to the event logger.
        # #####################################################################

        # Identity fields (originally from "identities" endpoint)
        identity_success: payroll_account.job_succeeded?("identity"),
        identity_supported: payroll_account.supported_jobs.include?("identity"),
        identity_count: report.identities.length,
        identity_full_name_present: report.identities.first&.full_name&.present?,
        identity_full_name_length: report.identities.first&.full_name&.length,
        identity_date_of_birth_present: report.identities.first&.date_of_birth.present?,
        identity_ssn_present: report.identities.first&.ssn.present?,
        identity_emails_count: report.identities.sum { |i| i.emails.length },
        identity_phone_numbers_count: report.identities.sum { |i| i.phone_numbers.length },

        # Income fields (originally from "identities" endpoint)
        income_success: payroll_account.job_succeeded?("income"),
        income_supported: payroll_account.supported_jobs.include?("income"),
        income_compensation_amount_present: report.incomes.first&.compensation_amount.present?,
        income_compensation_unit_present: report.incomes.first&.compensation_unit.present?,
        income_pay_frequency_present: report.incomes.first&.pay_frequency.present?,
        income_pay_frequency: report.incomes.first&.pay_frequency,

        # Paystubs fields
        paystubs_success: payroll_account.job_succeeded?("paystubs"),
        paystubs_supported: payroll_account.supported_jobs.include?("paystubs"),
        paystubs_count: report.paystubs.length,
        paystubs_deductions_count: report.paystubs.sum { |p| p.deductions.length },
        paystubs_hours_average: paystub_hours.sum.to_f / paystub_hours.length,
        paystubs_hours_by_earning_category_count: report.paystubs.sum { |p| p.hours_by_earning_category.length },
        paystubs_hours_max: paystub_hours.max,
        paystubs_hours_median: paystub_hours[paystub_hours.length / 2],
        paystubs_hours_min: paystub_hours.min,
        paystubs_hours_present: report.paystubs.first&.hours.present?,
        paystubs_earnings_count: report.paystubs.sum { |p| p.earnings.length },
        paystubs_earnings_with_hours_count: report.paystubs.sum { |p| p.earnings.count { |e| e.hours.present? } },
        paystubs_earnings_type_base_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "base" } },
        paystubs_earnings_type_bonus_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "bonus" } },
        paystubs_earnings_type_overtime_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "overtime" } },
        paystubs_earnings_type_commission_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "commission" } },
        paystubs_gross_pay_amounts_max: paystub_gross_pay_amounts.max,
        paystubs_gross_pay_amounts_median: paystub_gross_pay_amounts[paystub_gross_pay_amounts.length / 2],
        paystubs_gross_pay_amounts_average: paystub_gross_pay_amounts.sum.to_f / paystub_gross_pay_amounts.length,
        paystubs_gross_pay_amounts_min: paystub_gross_pay_amounts.min,

        # Employment fields (originally from "identities" endpoint)
        employment_success: payroll_account.job_succeeded?("employment"),
        employment_supported: payroll_account.supported_jobs.include?("employment"),
        employment_status: report.employments.first&.status,
        employment_employer_name: report.employments.first&.employer_name,
        employment_employer_address_present: report.employments.first&.employer_address&.present?,
        employment_employer_phone_number_present: report.employments.first&.employer_name&.present?,
        employment_start_date: report.employments.first&.start_date,
        employment_termination_date: report.employments.first&.termination_date,
        employment_type: report.employments.first&.employment_type&.to_s,
        employment_type_w2_count: report.employments.count { |e| e.employment_type == :w2 },
        employment_type_gig_count: report.employments.count { |e| e.employment_type == :gig },

        # Gigs fields
        gigs_success: payroll_account.job_succeeded?("gigs"),
        gigs_supported: payroll_account.supported_jobs.include?("gigs"),
        gigs_count: report.gigs.length,
        gigs_duration_present_count: report.gigs.count { |g| g.hours.present? },
        gigs_earning_type_adjustment_count: report.gigs.count { |g| g.compensation_category == "adjustment" },
        gigs_earning_type_incentive_count: report.gigs.count { |g| g.compensation_category == "incentive" },
        gigs_earning_type_offer_count: report.gigs.count { |g| g.compensation_category == "offer" },
        gigs_earning_type_other_count: report.gigs.count { |g| g.compensation_category == "other" },
        gigs_earning_type_work_count: report.gigs.count { |g| g.compensation_category == "work" },
        gigs_pay_present_count: report.gigs.count { |g| g.compensation_amount.present? },
        gigs_status_cancelled_count: report.gigs.count { |g| g.gig_status == "cancelled" },
        gigs_status_completed_count: report.gigs.count { |g| g.gig_status == "completed" },
        gigs_status_scheduled_count: report.gigs.count { |g| g.gig_status == "scheduled" },
        gigs_type_delivery_count: report.gigs.count { |g| g.gig_type == "delivery" },
        gigs_type_hourly_count: report.gigs.count { |g| g.gig_type == "hourly" },
        gigs_type_rideshare_count: report.gigs.count { |g| g.gig_type == "rideshare" },
        gigs_type_services_count: report.gigs.count { |g| g.gig_type == "services" }
      })
    rescue => ex
      raise ex unless Rails.env.production?

      Rails.logger.error "Unable to track event (in #{self.class.name}): #{ex}"
    end
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
      event_logger.track("ApplicantReportFailedUsefulRequirements", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        errors: report.errors.full_messages.join(", ")
      })
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to track event (in #{self.class.name}): #{ex}"
  ensure
    return report_is_valid
  end

  def update_synchronization_page(payroll_account)
    payroll_account.broadcast_replace(partial: "cbv/synchronizations/indicators", locals: { payroll_account: payroll_account })
  end
end
