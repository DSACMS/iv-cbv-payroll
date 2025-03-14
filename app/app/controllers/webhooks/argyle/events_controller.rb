class Webhooks::Argyle::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_argyle, :authorize_webhook
  after_action :track_events
  skip_before_action :verify_authenticity_token

  # To prevent timing attacks, we attempt to verify the webhook signature
  # using a same-length dummy key even if the user ID does not match a
  # valid `cbv_flow`.
  DUMMY_SECRET = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  # argyle's event outcomes are implied by the event name themselves i.e. accounts.failed (implies error)
  # users.fully_synced (implies success)
  EVENT_OUTCOMES = {
    "accounts.failed" => :error,
    "users.fully_synced" => :success
  }.freeze

  def create
    @payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(
      type: :argyle,
      pinwheel_account_id: @account_id # this column will be renamed to something more abstract later. it's not pinwheel specific.
    ) do |new_payroll_account|
      new_payroll_account.supported_jobs = determine_supported_jobs
    end

    @webhook_event = WebhookEvent.create!(
      payroll_account: @payroll_account,
      event_name: params["event"],
      event_outcome: EVENT_OUTCOMES[params["event"]],
    )

    render json: { status: "ok" }
  end

  private

  def handle_gigs_fully_synced
    PayrollAccount.find_by(type: :argyle, pinwheel_account_id: @account_id)
  end

  # @see https://docs.argyle.com/api-guide/webhooks
  def authorize_webhook
    signature = request.headers["X-Argyle-Signature"]

    # Use the configured secret or a dummy one
    secret = @argyle&.webhook_secret || DUMMY_SECRET

    unless verify_signature(signature, secret)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def verify_signature(signature, secret)
    @argyle.verify_signature(signature, request.raw_post, secret)
  end

  def set_cbv_flow
    cbv_user_id = params.dig("data", "resource", "id")
    @cbv_flow = CbvFlow.find_by_end_user_id(cbv_user_id)

    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow for Argyle account_id: #{account_id}"
      render json: { status: "ok" }
    end
  end

  def set_argyle
    @argyle = @cbv_flow.present? ? argyle_for(@cbv_flow) : ArgyleService.new("sandbox")
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
end
