class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def ma_dta
    response_params = request.env["omniauth.auth"]["info"]
    # TODO: Check that the email is permissible according to its domain
    @user = User.find_or_create_by(email: response_params["email"], site_id: :ma)

    if @user&.persisted?
      flash[:notice] = "Signed in!"
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "You have not yet an account!"
      redirect_back(fallback_location: root_path)
    end
  end
end
