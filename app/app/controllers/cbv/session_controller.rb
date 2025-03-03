class Cbv::SessionController < ApplicationController
  def refresh
    session[:last_seen] = Time.current
    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to request.referrer || root_path }
    end
  end
end
