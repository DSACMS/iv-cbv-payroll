class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def nyc_dss
    response_params = request.env["omniauth.auth"]["info"]
    email = response_params["email"]

    login_with_oauth(email, "nyc")
  end

  def ma_dta
    response_params = request.env["omniauth.auth"]["info"]
    email = response_params["email"]

    login_with_oauth(email, "ma")
  end

  def sandbox
    response_params = request.env["omniauth.auth"]["info"]
    email = response_params["email"]

    login_with_oauth(email, "sandbox")
  end

  private

  def login_with_oauth(email, site_id)
    # TODO: Check that the email is permissible according to its domain
    @user = User.find_or_create_by(email: email, site_id: site_id)

    if @user&.persisted?
      flash[:notice] = "Signed in!"
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "Something went wrong."
    end
  end
end
