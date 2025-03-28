class Webhooks::Argyle::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_argyle, :authorize_webhook, :set_argyle_account_id
  after_action :track_events
  skip_before_action :verify_authenticity_token

  # To prevent timing attacks, we attempt to verify the webhook signature
  # using a same-length dummy key even if the user ID does not match a
  # valid `cbv_flow`.
  DUMMY_SECRET = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  def create
    # Handle the users.fully_synced event with potentially multiple accounts.
    # If users add more than one account then this array will contain the IDs
    # of all the accounts that were connected. In this instance we need to
    # iterate over the accounts and process a webhook event for each account.
    if params["event"] == "users.fully_synced"
      handle_users_fully_synced
    end

    # This condition is met when an Argyle webhook contains a single "account" value in the payload
    if @argyle_account_id.present?
      @payroll_account = process_account(@argyle_account_id, params["event"])
    end

    render json: { status: "ok" }
  end

  private

  def handle_users_fully_synced
    accounts_connected = params.dig("data", "resource", "accounts_connected")

    if accounts_connected.present?
      # Get the payroll accounts that do not have a webhook event for "users.fully_synced"
      # rather than iterating over each account entry that Argyle sends back.
      #
      # In the event that a user adds multiple payroll accounts we do not want to
      # record duplicate webhook events
      payroll_accounts_to_sync = @cbv_flow.payroll_accounts.where.not(
        id: @cbv_flow.payroll_accounts
              .joins(:webhook_events)
              .where(webhook_events: { event_name: params["event"] })
      ).to_a

      # Handle each connected account separately
      payroll_accounts_to_sync.each do |account|
        process_account(account.pinwheel_account_id, params["event"])
      end
    end
  end

  def process_account(account_id, event_name)
    payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(
      type: :argyle,
      pinwheel_account_id: account_id
    ) do |new_payroll_account|
      new_payroll_account.supported_jobs = @argyle_service.get_supported_jobs
    end

    webhook_event = WebhookEvent.create!(
      payroll_account: payroll_account,
      event_name: event_name,
      event_outcome: @argyle_service.get_webhook_event_outcome(event_name)
    )

    # Set instance variables for the current account being processed
    # This is needed for the track_events callback
    if event_name == params["event"] && account_id == @argyle_account_id
      @payroll_account = payroll_account
      @webhook_event = webhook_event
    end

    payroll_account
  end

  # @see https://docs.argyle.com/api-guide/webhooks
  def authorize_webhook
    # ignore any webhooks that are not in the list of supported webhook events
    return unless @argyle_service.get_webhook_events.include?(params["event"])

    unless @argyle_service.verify_signature(request.headers["X-Argyle-Signature"], request.raw_post)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def set_argyle_account_id
    @argyle_account_id = params.dig("data", "account")
  end

  def set_cbv_flow
    argyle_user_id = params.dig("data", "user")

    @cbv_flow = CbvFlow.where(end_user_id: argyle_user_id).order(created_at: :desc).first

    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow for Argyle with account: #{@argyle_account_id}"
      render json: { status: "ok" }
    end
  end

  def set_argyle
    account_type = Rails.env.production? ? "production" : "sandbox"
    @argyle_service = @cbv_flow.present? ? argyle_for(@cbv_flow) : ArgyleService.new(account_type)
  end

  def track_events
    return unless @webhook_event

    if @webhook_event.event_name == "accounts.connected"
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
end
