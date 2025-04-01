class Webhooks::Pinwheel::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_pinwheel, :authorize_webhook
  after_action :track_events, :update_synchronization_page
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

    if @payroll_account.has_fully_synced?
      PaystubsChannel.broadcast_to(@cbv_flow, {
        event: "cbv.status_update",
        account_id: params["payload"]["account_id"],
        has_fully_synced: true
      })
    end
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

  def track_events
    if @webhook_event.event_name == "account.added"
      event_logger.track("ApplicantCreatedPinwheelAccount", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        platform_name: params["payload"]["platform_name"]
      })
    elsif @payroll_account.has_fully_synced?
      event_logger.track("ApplicantFinishedPinwheelSync", request, {
        cbv_applicant_id: @cbv_flow.cbv_applicant_id,
        cbv_flow_id: @cbv_flow.id,
        invitation_id: @cbv_flow.cbv_flow_invitation_id,
        identity_success: @payroll_account.job_succeeded?("identity"),
        identity_supported: @payroll_account.supported_jobs.include?("identity"),
        income_success: @payroll_account.job_succeeded?("income"),
        income_supported: @payroll_account.supported_jobs.include?("income"),
        paystubs_success: @payroll_account.job_succeeded?("paystubs"),
        paystubs_supported: @payroll_account.supported_jobs.include?("paystubs"),
        employment_success: @payroll_account.job_succeeded?("employment"),
        employment_supported: @payroll_account.supported_jobs.include?("employment"),
        sync_duration_seconds: Time.now - @payroll_account.created_at
      })
    end
  rescue => ex
    raise ex unless Rails.env.production?

    Rails.logger.error "Unable to track NewRelic event (in #{self.class.name}): #{ex}"
  end

  def update_synchronization_page
    @payroll_account.broadcast_replace(partial: "cbv/synchronizations/indicators", locals: { pinwheel_account: @payroll_account })
  end
end
