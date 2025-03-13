class Webhooks::Argyle::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_argyle, :authorize_webhook
  after_action :track_events, :update_synchronization_page
  skip_before_action :verify_authenticity_token

  # To prevent timing attacks, we attempt to verify the webhook signature
  # using a same-length dummy key even if the user ID does not match a
  # valid `cbv_flow`.
  DUMMY_SECRET = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  def create

    # Handle different event types
    case params["event"]
    when "accounts.connected"
      handle_account_connected
    when "gigs.fully_synced"
      handle_gigs_fully_synced
      # Handle other event types as needed
    end

    # Record the webhook event
    if @payroll_account
      @webhook_event = WebhookEvent.create!(
        payroll_account: @payroll_account,
        event_name: params["event"],
        event_outcome: determine_event_outcome,
      )
    end

    # Broadcast status updates if needed
    if @payroll_account&.has_fully_synced?
      PaystubsChannel.broadcast_to(@cbv_flow, {
        event: "cbv.status_update",
        account_id: @payroll_account.pinwheel_account_id,
        has_fully_synced: true
      })
    end

    render json: { status: "ok" }
  end

  private

  def handle_account_connected
    account_id = params.dig("data", "resource", "id")

    # If we already have a CbvFlow from set_cbv_flow, use that
    if @cbv_flow
      @payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(
        type: :argyle,
        pinwheel_account_id: account_id
      ) do |new_payroll_account|
        new_payroll_account.supported_jobs = determine_supported_jobs
      end
    else
      # Find the first CbvFlow that doesn't have an Argyle account yet
      @cbv_flow = CbvFlow.joins("LEFT JOIN payroll_accounts ON payroll_accounts.cbv_flow_id = cbv_flows.id AND payroll_accounts.type = 'argyle'")
                         .where("payroll_accounts.id IS NULL")
                         .first

      if @cbv_flow
        @payroll_account = @cbv_flow.payroll_accounts.create!(
          type: :argyle,
          pinwheel_account_id: account_id,
          supported_jobs: determine_supported_jobs
        )
      else
        Rails.logger.info "No CbvFlow without an Argyle account found for new connection"
      end
    end
  end

  def handle_gigs_fully_synced
    # Find the appropriate payroll account based on the account ID in the webhook
    account_id = params.dig("data", "account")
    @payroll_account = PayrollAccount.find_by(type: :argyle, pinwheel_account_id: account_id)

    # If we found the payroll account but not the cbv_flow, set it now
    @cbv_flow ||= @payroll_account&.cbv_flow
  end

  def authorize_webhook
    signature = request.headers["X-Argyle-Signature"]

    # Use the configured secret or a dummy one
    secret = @argyle&.webhook_secret || DUMMY_SECRET

    unless verify_signature(signature, secret)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def verify_signature(signature, secret)
    return true if Rails.env.test? && !signature.present?

    @argyle.verify_signature(signature, request.raw_post, secret)
  end

  def set_cbv_flow
    # Extract user ID and account ID from the webhook
    user_id = params.dig("data", "user")
    account_id = params.dig("data", "resource", "id") || params.dig("data", "account")

    if account_id.present?
      # First try to find an existing PayrollAccount with this account ID
      payroll_account = PayrollAccount.find_by(type: :argyle, pinwheel_account_id: account_id)
      @cbv_flow = payroll_account&.cbv_flow
    end

    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow for Argyle account_id: #{account_id}"
      render json: { status: "ok" }
    end
  end

  def set_argyle
    @argyle = @cbv_flow.present? ? argyle_for(@cbv_flow) : ArgyleService.new("sandbox")
  end

  def determine_event_outcome
    params.dig("data", "error").present? ? "error" : "success"
  end

  def determine_supported_jobs
    PayrollAccount::Argyle.available_jobs
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

  def update_synchronization_page
    return unless @payroll_account

    @payroll_account.broadcast_replace(
      partial: "cbv/synchronizations/indicators",
      locals: { argyle_account: @payroll_account }
    )
  rescue => ex
    Rails.logger.error "Unable to update synchronization page: #{ex}"
  end
end
