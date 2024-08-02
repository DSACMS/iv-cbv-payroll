class Webhooks::Pinwheel::EventsController < ApplicationController
  DUMMY_API_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

  skip_before_action :verify_authenticity_token

  def create
    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    # To prevent timing attacks, we attempt to verify the webhook signature
    # using a same-length DUMMY_API_KEY even if the `end_user_id` does not
    # match a valid `cbv_flow`.
    cbv_flow = CbvFlow.find_by_pinwheel_end_user_id(params["payload"]["end_user_id"])
    pinwheel = cbv_flow.present? ? pinwheel_for(cbv_flow) : PinwheelService.new(DUMMY_API_KEY)
    digest = pinwheel.generate_signature_digest(timestamp, request.raw_post)
    unless pinwheel.verify_signature(signature, digest)
      return render json: { error: "Invalid signature" }, status: :unauthorized
    end

    if params["event"] == "paystubs.ninety_days_synced"
      if cbv_flow
        cbv_flow.update(payroll_data_available_from: params["payload"]["params"]["from_pay_date"])
        PaystubsChannel.broadcast_to(cbv_flow, params)
      end
    end
  end
end
