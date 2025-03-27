class Webhooks::Argyle::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_argyle, :authorize_webhook
  after_action :track_events
  skip_before_action :verify_authenticity_token

  # To prevent timing attacks, we attempt to verify the webhook signature
  # using a same-length dummy key even if the user ID does not match a
  # valid `cbv_flow`.
  DUMMY_SECRET = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  def create
    @payroll_account = @cbv_flow.payroll_accounts.find_or_create_by(
      type: :argyle,
      pinwheel_account_id: @argyle_account_id
    ) do |new_payroll_account|
      new_payroll_account.supported_jobs = @argyle_service.get_supported_jobs
    end

    # update the payroll [event]_synced_at timestamps
    if @argyle_service.get_webhook_event_outcome(params["event"]) == :success
      job_names = @argyle_service.get_webhook_event_jobs(params["event"])
      if job_names.present?
        job_names.each do |job_name|
          timestamp_attr = "#{job_name}_synced_at"
          @payroll_account.update("#{timestamp_attr}": Time.now)
        end
      end
    end

    @webhook_event = WebhookEvent.create!(
      payroll_account: @payroll_account,
      event_name: params["event"],
      event_outcome: @argyle_service.get_webhook_event_outcome(params["event"]),
    )

    # TODO: uncomment this if we want to broadcast Argyle fully synced to the frontend
    #
    # if @payroll_account.has_fully_synced?
    #   PaystubsChannel.broadcast_to(@cbv_flow, {
    #     event: "cbv.status_update",
    #     account_id: params["data"]["external_id"],
    #     has_fully_synced: true
    #   })
    # end

    render json: { status: "ok" }
  end

  private

  # @see https://docs.argyle.com/api-guide/webhooks
  def authorize_webhook
    # ignore any webhooks that are not in the list of supported webhook events
    return unless @argyle_service.get_webhook_events.include?(params["event"])

    unless @argyle_service.verify_signature(request.headers["X-Argyle-Signature"], request.raw_post)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def set_cbv_flow
    argyle_user_id = params.dig("data", "user")
    @argyle_account_id = params.dig("data", "account")
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
