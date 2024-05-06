class Api::ArgyleController < ApplicationController
  skip_before_action :verify_authenticity_token

  USER_TOKEN_ENDPOINT = 'https://api-sandbox.argyle.com/v2/user-tokens';

  def update_token
    cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    new_token = refresh_token(cbv_flow.argyle_user_id)

    render json: { status: :ok, token: new_token['user_token'] }
  end

  private

  def refresh_token(argyle_user_id)
    res = Net::HTTP.post(
      URI.parse(USER_TOKEN_ENDPOINT),
      { "user": argyle_user_id }.to_json,
      {
        "Authorization" => "Basic #{Rails.application.credentials.argyle[:api_key]}",
        "Content-Type" => "application/json"
      }
    )

    JSON.parse(res.body)
  end
end
