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

    if params["event"] == "accounts.added"
      rep = ConnectedArgyleAccount.create!(
        user_id: params["payload"]["end_user_id"],
        account_id: params["payload"]["link_token_id"]
      )
      Rails.logger.info "ConnectedArgyleAccount created: #{rep}"
      render json: { message: "ConnectedArgyleAccount created", data: rep }, status: :created
    end
  end

  def provider
    PinwheelService.new
  end
end

# # Technology Stack: Node.js, Express.js

# require 'openssl'
# require 'digest'

# def verify_signature(signature, timestamp, raw_body)
#   prefix = Buffer.from("v2:#{timestamp}:", 'utf8')
#   message = Buffer.concat([prefix, raw_body])
#   digest = OpenSSL::HMAC.hexdigest('sha256', ENV['YOUR_PINWHEEL_API_SECRET'].encode('utf-8'), message)
#   generated_signature = "v2=#{digest}"

#   buf_sig = Buffer.from(signature)
#   buf_gen = Buffer.from(generated_signature)

#   return buf_sig.length == buf_gen.length && OpenSSL::TimingSafeEqual.timingSafeEqual(buf_sig, buf_gen)
# end

# auth_middleware = Express.json(verify: ->(request, response, buffer) {
#   signature = request.headers['x-pinwheel-signature']
#   timestamp = request.headers['x-timestamp']

#   unless verify_signature(signature, timestamp, buffer)
#     raise 'Invalid webhook request signature'
#   end
# })
