class Webhooks::Pinwheel::EventsController < ApplicationController
  before_action :authorize_webhook
  skip_before_action :verify_authenticity_token

  DUMMY_API_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  EVENTS_MAP = {
    "employment.added" => "employment_synced_at",
    "income.added" => "income_synced_at",
    "paystubs.fully_synced" => "paystubs_synced_at"
  }

  def authorize_webhook
    # To prevent timing attacks, we attempt to verify the webhook signature
    # using a same-length DUMMY_API_KEY even if the `end_user_id` does not
    # match a valid `cbv_flow`.
    cbv_flow = CbvFlow.find_by_pinwheel_end_user_id(params["payload"]["end_user_id"])
    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    pinwheel = cbv_flow.present? ? pinwheel_for(cbv_flow) : PinwheelService.new(DUMMY_API_KEY, "sandbox")
    digest = pinwheel.generate_signature_digest(timestamp, request.raw_post)
    unless pinwheel.verify_signature(signature, digest)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end

  def create
    cbv_flow = CbvFlow.find_by_pinwheel_end_user_id(params["payload"]["end_user_id"])

    if cbv_flow && params["event"] == "account.added"
      pinwheel_account = PinwheelAccount.find_or_create_by(pinwheel_account_id: params["payload"]["account_id"])
      pinwheel_account.update!(cbv_flow: cbv_flow)
    end

    if cbv_flow && EVENTS_MAP.keys.include?(params["event"])
      pinwheel_account = PinwheelAccount.find_by_pinwheel_account_id(params["payload"]["account_id"])
      pinwheel_account.update!(EVENTS_MAP[params["event"]] => Time.now) if pinwheel_account.present?

      if pinwheel_account.has_full_synced?
        PaystubsChannel.broadcast_to(cbv_flow, {
          event: "cbv.payroll_data_available",
          account_id: params["payload"]["account_id"]
        })
      end
    end
  end
end
