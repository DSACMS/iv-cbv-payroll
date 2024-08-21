class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def nyc_dss
    response_params = request.env["omniauth.auth"]["info"]
    Rails.logger.info "Login successful from #{response_params["email"]} (name: #{response_params["name"]}, nickname: #{response_params["nickname"]})"
    email = response_params["email"]

    login_with_oauth(email, "nyc")
  end

  def ma_dta
    response_params = request.env["omniauth.auth"]["info"]
    Rails.logger.info "Login successful from #{response_params["email"]} (name: #{response_params["name"]}, nickname: #{response_params["nickname"]})"
    email = response_params["email"]

    login_with_oauth(email, "ma")
  end

  def sandbox
    response_params = request.env["omniauth.auth"]["info"]
    Rails.logger.info "Login successful from #{response_params["email"]} (name: #{response_params["name"]}, nickname: #{response_params["nickname"]})"
    email = response_params["email"]

    login_with_oauth(email, "sandbox")
  end

  private

  def login_with_oauth(email, site_id)
    # TODO: Check that the email is permissible according to its domain
    @user = User.find_for_authentication(email: email, site_id: site_id)
    @user ||= User.create(email: email, site_id: site_id)

    if @user&.persisted?
      flash[:slim_alert] = { message: t("users.omniauth_callbacks.authentication_successful"), type: "info" }
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "Something went wrong."
    end
  end
end
