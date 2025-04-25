class Api::ArgyleController < ApplicationController
  after_action :track_event

  # This API endpoint is used to fetch a `user_token` to allow the user to open
  # the Argyle modal.
  #
  # @see https://docs.argyle.com/link/user-tokens
  def create
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    argyle = argyle_for(@cbv_flow)
    item_id = params[:item_id]

    is_sandbox_environment = agency_config[@cbv_flow.client_agency_id].argyle_environment == "sandbox"
    user_token = if @cbv_flow.argyle_user_id.blank?
                   response = argyle.create_user(@cbv_flow.end_user_id)

                   # Store the argyle_user_id to allow us to associate incoming webhooks with
                   # this CbvFlow.
                   @cbv_flow.update(argyle_user_id: response["id"])

                   response["user_token"]
                 else
                   # If the user has already been created in Argyle, let's just
                   # make them a new link token with the same user.
                   response = argyle.create_user_token(@cbv_flow.argyle_user_id)
                   response["user_token"]
                 end

    # Redirect if the user is attempting connect a previously connected account
    argyle_user = argyle.fetch_user_api(user: @cbv_flow.argyle_user_id)
    payroll_account = PayrollAccount::Argyle.find_by(cbv_flow: @cbv_flow)

    if item_id.present? && argyle_user["items_connected"]&.include?(item_id)

      if payroll_account&.has_fully_synced?
        return redirect_to cbv_flow_payment_details_path(user: { account_id: payroll_account.pinwheel_account_id })
      else
        return redirect_to cbv_flow_synchronizations_path(user: { account_id: payroll_account.pinwheel_account_id })
      end
    end

    render json: {
      status: :ok,
      isSandbox: is_sandbox_environment,
      flowId: Aggregators::Sdk::ArgyleService::FLOW_ID,
      user: {
        user_token: user_token
      }
    }
  end

  def track_event
    event_logger.track("ApplicantBeganLinkingEmployer", request, {
      cbv_flow_id: @cbv_flow.id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id
    })
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantBeganLinkingEmployer): #{ex}"
  end
end
