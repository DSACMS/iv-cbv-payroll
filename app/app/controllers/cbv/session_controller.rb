class Cbv::SessionController < ApplicationController
  def refresh
    session[:last_seen] = Time.current
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update("session-status", "Session extended successfully!") }
    end
  end

  # should we use the resets_controller for this?
  def destroy
    session[:cbv_flow_id] = nil
    if params[:user_action] == "false"
      track_timeout_event
    end
    redirect_to root_url
  end
end
