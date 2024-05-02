class Webhooks::Argyle::EventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    digest = OpenSSL::Digest.new('sha512')
    signature = OpenSSL::HMAC.hexdigest('SHA512', ENV['ARGYLE_WEBHOOK_SECRET'], request.raw_post)

    if request.headers["X-Argyle-Signature"] == signature
      if params['event'] == 'paystubs.fully_synced' || params['event'] == 'paystubs.partially_synced'
        @cbv_flow = CbvFlow.find_by_argyle_user_id(params['data']['user'])

        if @cbv_flow
          @cbv_flow.update(payroll_data_available_from: params['data']['available_from'])
          ArgylePaystubsChannel.broadcast_to(@cbv_flow, params)
        end
      end
    else
      render json: { error: 'Invalid signature' }, status: :unauthorized
    end
  end
end
