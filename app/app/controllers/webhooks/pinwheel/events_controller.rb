class Webhooks::Pinwheel::EventsController < ApplicationController
  DUMMY_API_KEY = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
  EVENTS = %w[
    employment.added
    income.added
    paystubs.fully_synced
  ]

  skip_before_action :verify_authenticity_token

  def create
    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    # To prevent timing attacks, we attempt to verify the webhook signature
    # using a same-length DUMMY_API_KEY even if the `end_user_id` does not
    # match a valid `cbv_flow`.
    cbv_flow = CbvFlow.find_by_pinwheel_end_user_id(params["payload"]["end_user_id"])
    pinwheel = cbv_flow.present? ? pinwheel_for(cbv_flow) : PinwheelService.new(DUMMY_API_KEY, "sandbox")
    digest = pinwheel.generate_signature_digest(timestamp, request.raw_post)
    unless pinwheel.verify_signature(signature, digest)
      return render json: { error: "Invalid signature" }, status: :unauthorized
    end

    if EVENTS.include?(params["event"]) && cbv_flow
      cbv_flow.events << params["event"] && cbv_flow.save

      if EVENTS.all? { |event| cbv_flow.events.include?(event) }
        # reset events for future payroll accounts
        cbv_flow.update(events: [])
        PaystubsChannel.broadcast_to(cbv_flow, {
          event: "cbv.payroll_data_available",
          account_id: params["payload"]["account_id"]
        })
      end
    end
  end
end
