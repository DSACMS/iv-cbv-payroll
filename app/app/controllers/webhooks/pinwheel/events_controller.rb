class Webhooks::Pinwheel::EventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    signature = request.headers["X-Pinwheel-Signature"]
    timestamp = request.headers["X-Timestamp"]

    digest = provider.generate_signature_digest(timestamp, request.raw_post)

    unless provider.verify_signature(signature, digest)
      return render json: { error: "Invalid signature" }, status: :unauthorized
    end

    if params["event"] == "paystubs.added"
      @cbv_flow = CbvFlow.find_by_pinwheel_token_id(params["payload"]["link_token_id"])

      if @cbv_flow
        @cbv_flow.update(payroll_data_available_from: params["payload"]["params"]["from_pay_date"])
        PinwheelPaystubsChannel.broadcast_to(@cbv_flow, params)
      end
    end
  end

  def provider
    PinwheelService.new
  end
end
