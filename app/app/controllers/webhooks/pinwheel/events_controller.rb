class Webhooks::Pinwheel::EventsController < ApplicationController
  before_action :set_cbv_flow, :set_pinwheel, :authorize_webhook
  skip_before_action :verify_authenticity_token

  DUMMY_API_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  def create
    unless @cbv_flow
      Rails.logger.info "Unable to find CbvFlow for end_user_id: #{params["payload"]["end_user_id"]}"
      return render json: { status: "ok" }
    end

    if params["event"] == "account.added"
      supported_jobs = get_supported_jobs(params["payload"]["platform_id"])
      PinwheelAccount
        .create_with(cbv_flow: @cbv_flow, supported_jobs: supported_jobs)
        .find_or_create_by(pinwheel_account_id: params["payload"]["account_id"])
    end

    if PinwheelAccount::EVENTS_MAP.keys.include?(params["event"])
      pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(params["payload"]["account_id"])
      pinwheel_account.update!(PinwheelAccount::EVENTS_MAP[params["event"]] => Time.now) if pinwheel_account.present?

      if params.dig("payload", "outcome") == "error"
        pinwheel_account.update!(PinwheelAccount::EVENTS_ERRORS_MAP[params["event"]] => Time.now) if pinwheel_account.present?
      end

      if pinwheel_account.has_fully_synced?
        PaystubsChannel.broadcast_to(@cbv_flow, {
          event: "cbv.payroll_data_available",
          account_id: params["payload"]["account_id"]
        })
      end
    end
  end

  private

  def authorize_webhook
    # To prevent timing attacks, we attempt to verify the webhook signature
    # using a same-length DUMMY_API_KEY even if the `end_user_id` does not
    # match a valid `cbv_flow`.

    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    digest = @pinwheel.generate_signature_digest(timestamp, request.raw_post)
    unless @pinwheel.verify_signature(signature, digest)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def set_cbv_flow
    @cbv_flow = CbvFlow.find_by_pinwheel_end_user_id(params["payload"]["end_user_id"])
  end

  def set_pinwheel
    @pinwheel = @cbv_flow.present? ? pinwheel_for(@cbv_flow) : PinwheelService.new(DUMMY_API_KEY, "sandbox")
  end

  def get_supported_jobs(platform_id)
    @pinwheel.fetch_platform(platform_id: platform_id)["data"]["supported_jobs"]
  end
end
