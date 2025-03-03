class Cbv::SessionController < ApplicationController
  def refresh
    session[:last_seen] = Time.current
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to request.referrer || root_path }
    end
  end

  def end
    if params[:timeout] == "true"
      track_timeout_event
    end

    session[:cbv_flow_id] = nil
    redirect_to root_url
  end
end
