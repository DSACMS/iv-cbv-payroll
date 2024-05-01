class Webhooks::Argyle::EventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    if params['event'] == 'paystubs.fully_synced'
      @cbv_flow = CbvFlow.find_by_argyle_user_id(params['data']['user'])

      if @cbv_flow
        @cbv_flow.update(payroll_data_available_from: params['data']['available_from'])
        ArgylePaystubsChannel.broadcast_to(@cbv_flow, params['data']['available_from'])
      end
    end
  end
end
