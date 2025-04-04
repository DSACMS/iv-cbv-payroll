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
        track_events(webhook_event)
      end
    else
      # All other webhooks have a params["data"]["account"], which we can use
      # to find the account.
      account_id = params.dig("data", "account")
      payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(type: :argyle, pinwheel_account_id: account_id) do |new_payroll_account|
        new_payroll_account.supported_jobs = Webhooks::Argyle.get_supported_jobs
      end

      webhook_event = create_webhook_event_for_account(params["event"], payroll_account)
      update_synchronization_page(payroll_account)
      track_events(webhook_event)
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
      event_outcome: Webhooks::Argyle.get_webhook_event_outcome(event_name)
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

    unless Webhooks::Argyle.get_webhook_events.include?(params["event"])
      render json: { info: "Unhandled webhook" }, status: :ok
    end

    unless Webhooks::Argyle.verify_signature(request.headers["X-Argyle-Signature"], request.raw_post, argyle_service.webhook_secret)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def track_events(webhook_event)
    if webhook_event.event_name == "accounts.connected"
      event_logger.track("ApplicantCreatedArgyleAccount", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        provider_name: params.dig("data", "resource", "providers_connected")&.first
      })
    elsif @payroll_account&.has_fully_synced?
      event_logger.track("ApplicantFinishedArgyleSync", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        identities_success: @payroll_account.job_succeeded?("identities"),
        identities_supported: @payroll_account.supported_jobs.include?("identities"),
        paystubs_success: @payroll_account.job_succeeded?("paystubs"),
        paystubs_supported: @payroll_account.supported_jobs.include?("paystubs"),
        gigs_success: @payroll_account.job_succeeded?("gigs"),
        gigs_supported: @payroll_account.supported_jobs.include?("gigs"),
        sync_duration_seconds: Time.now - @payroll_account.created_at
      })
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to track event (in #{self.class.name}): #{ex}"
  end

  def update_synchronization_page(payroll_account)
    payroll_account.broadcast_replace(partial: "cbv/synchronizations/indicators", locals: { pinwheel_account: payroll_account })
  end
end
