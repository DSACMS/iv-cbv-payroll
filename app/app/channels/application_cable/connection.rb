module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :cbv_flow_id

    def session
      @request.session
    end

    def cbv_flow_id
      session[:cbv_flow_id]
    end
  end
end
