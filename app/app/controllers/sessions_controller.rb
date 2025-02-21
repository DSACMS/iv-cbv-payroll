class SessionsController < ApplicationController
  def extend
    # Reset the Devise timeout timer
    request.env['devise.skip_timeout'] = true
    current_user.try(:remember_me!)
    current_user.try(:remember_me=, true)
    sign_in(current_user, force: true)

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("session-timeout-modal") }
      format.html { redirect_back(fallback_location: root_path) }
    end
  end
end 