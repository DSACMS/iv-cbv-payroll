class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def ma_dta
    response_params = request.env['omniauth.auth']['info']
    @user = User.find_by!(email: response_params['email'])
    
    if @user&.persisted?
      sign_in_and_redirect @user, event: :authentication
    else
      flash[:danger] = 'You have not yet an account!'
      redirect_back(fallback_location: root_path)
    end
  end
end
