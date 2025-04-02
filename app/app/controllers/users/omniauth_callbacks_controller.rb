class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  after_action :track_event

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

    if authorized?(email, "ma")
      login_with_oauth(email, "ma")
    else
      flash[:alert] = "You are not authorized to access this site. Please contact your administrator."
      redirect_to root_path
    end
  end

  def az_des
    response_params = request.env["omniauth.auth"]["info"]
    Rails.logger.info "Login successful from #{response_params["email"]} (name: #{response_params["name"]}, nickname: #{response_params["nickname"]})"
    email = response_params["email"]

    login_with_oauth(email, "az_des")
  end

  def sandbox
    response_params = request.env["omniauth.auth"]["info"]
    Rails.logger.info "Login successful from #{response_params["email"]} (name: #{response_params["name"]}, nickname: #{response_params["nickname"]})"
    email = response_params["email"]

    login_with_oauth(email, "sandbox")
  end

  private

  def login_with_oauth(email, client_agency_id)
    # TODO: Check that the email is permissible according to its domain
    @user = User.find_for_authentication(email: email, client_agency_id: client_agency_id)
    @user ||= User.create(email: email, client_agency_id: client_agency_id)

    if @user&.persisted?
      flash[:slim_alert] = { message: t("users.omniauth_callbacks.authentication_successful"), type: "info" }
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:alert] = "Something went wrong."
    end
  end

  def authorized?(email, client_agency)
    authorized_emails = Rails.application.config.client_agencies["ma"].authorized_emails&.split(",").map(&:downcase)

    unless authorized_emails.blank?
      authorized_emails.include?(email.downcase)
    end
  end

  def track_event
    return unless @user&.persisted?

    event_logger.track("CaseworkerLogin", request, {
      client_agency_id: @user.client_agency_id,
      user_id: @user.id
    })
  end

  def after_omniauth_failure_path_for(scope)
    case failed_strategy.name
    when "sandbox"
      new_user_session_path(client_agency_id: "sandbox")
    when "nyc_dss"
      new_user_session_path(client_agency_id: "nyc")
    when "ma_dta"
      new_user_session_path(client_agency_id: "ma")
    end
  end
end
