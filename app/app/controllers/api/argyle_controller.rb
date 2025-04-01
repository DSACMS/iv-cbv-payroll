class Api::ArgyleController < ApplicationController

  # This API endpoint is used to associate the user's CbvFlow
  # with a user_token and user id (id) supplied by Argyle.
  # This enables the client to retrieve an Argyle user_token to open
  # the Argyle modal or create an Argyle Link. It also provides a means
  # to associate an incoming webhook request sent by Argyle with an instance
  # of CBV PayrollAccount::Argyle
  #
  # @see https://docs.argyle.com/link/user-tokens
  def create
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    argyle = argyle_for(@cbv_flow)
    argyle.create_user(@cbv_flow.end_user_id) => {id:, user_token:}

    @cbv_flow.update({
      pinwheel_token_id: user_token,
      end_user_id: id
    })

    render json: { status: :ok, user_token: user_token }
  end
end
