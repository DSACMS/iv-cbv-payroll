class Api::ArgyleController < ApplicationController
  def create
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    argyle = argyle_for(@cbv_flow)
    argyle.create_user(@cbv_flow.end_user_id) => {id:, user_token:}

    # CbvFlow.end_user_id is automatically generated
    # We need to update the CbvFlow with the Argyle user ID so we can
    # associate the Argyle user with the CbvFlow.
    # Providing an initial external_id to Argyle does not always
    # result in Argyle webhooks returning the custom external_id
    # so we cannot rely on Argyle to provide the "external_id" .e.g
    # the auto-generated CbvFlow.end_user_id in the webhook response
    @cbv_flow.update({
      pinwheel_token_id: user_token,
      end_user_id: id
    })

    render json: { status: :ok, user_token: user_token }
  end
end
