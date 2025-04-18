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
        new_payroll_account.supported_jobs = Aggregators::Webhooks::Argyle.get_supported_jobs
      end

      webhook_event = create_webhook_event_for_account(params["event"], payroll_account)
      update_synchronization_page(payroll_account)
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

    unless Aggregators::Webhooks::Argyle.get_webhook_events.include?(params["event"])
      render json: { info: "Unhandled webhook" }, status: :ok
    end

    unless Aggregators::Webhooks::Argyle.verify_signature(request.headers["X-Argyle-Signature"], request.raw_post, argyle_service.webhook_secret)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
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
    elsif payroll_account&.has_fully_synced?
      report = Aggregators::AggregatorReports::ArgyleReport.new(
        payroll_accounts: [ payroll_account ],
        argyle_service: argyle_for(@cbv_flow),
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date
      )
      report.fetch
      log_sync_finish(payroll_account, report)
      validate_useful_report_requirements(report)
    end
  end

  def log_sync_finish(payroll_account, report)
    begin
      event_logger.track("ApplicantFinishedArgyleSync", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        sync_duration_seconds: Time.now - payroll_account.created_at,

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

        # Paystubs fields
        paystubs_success: payroll_account.job_succeeded?("paystubs"),
        paystubs_supported: payroll_account.supported_jobs.include?("paystubs"),
        paystubs_count: report.paystubs.length,
        paystubs_deductions_count: report.paystubs.sum { |p| p.deductions.length },
        paystubs_hours_by_earning_category_count: report.paystubs.sum { |p| p.hours_by_earning_category.length },
        paystubs_hours_present: report.paystubs.first&.hours.present?,
        paystubs_earnings_count: report.paystubs.sum { |p| p.earnings.length },
        paystubs_earnings_with_hours_count: report.paystubs.sum { |p| p.earnings.count { |e| e.hours.present? } },
        paystubs_earnings_type_base_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "base" } },
        paystubs_earnings_type_bonus_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "bonus" } },
        paystubs_earnings_type_overtime_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "overtime" } },
        paystubs_earnings_type_commission_count: report.paystubs.sum { |p| p.earnings.count { |e| e.category == "commission" } },

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
        gigs_supported: payroll_account.supported_jobs.include?("gigs")
        # TODO: Add fields from /gigs after FFS-2575.
      })
    rescue => ex
      raise ex unless Rails.env.production?

      Rails.logger.error "Unable to track event (in #{self.class.name}): #{ex}"
    end
  end

  def validate_useful_report_requirements(report)
    if report.valid?(:useful_report)
      event_logger.track("ApplicantReportMetUsefulRequirements", request, {})
    else
      event_logger.track("ApplicantReportFailedUsefulRequirements", request, {
        errors: report.errors.full_messages.join(", ")
      })
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to track event (in #{self.class.name}): #{ex}"
  end

  def update_synchronization_page(payroll_account)
    payroll_account.broadcast_replace(partial: "cbv/synchronizations/indicators", locals: { payroll_account: payroll_account })
  end
end
