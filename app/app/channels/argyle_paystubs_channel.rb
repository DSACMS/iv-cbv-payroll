class ArgylePaystubsChannel < ApplicationCable::Channel
  def subscribed
    cbv_flow = CbvFlow.find(connection.session[:cbv_flow_id])
    stream_for cbv_flow
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
