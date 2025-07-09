class Api::ArgyleController < ApplicationController
  before_action :set_cbv_flow, :resume_previous_argyle_account_connection
  after_action :track_event

  # This API endpoint is used to fetch a `user_token` to allow the user to open
  # the Argyle modal.
  #
  # @see https://docs.argyle.com/link/user-tokens
  def create
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

    render json: {
      status: :ok,
      isSandbox: is_sandbox_environment,
      flowId: Aggregators::Sdk::ArgyleService::FLOW_ID,
      user: {
        user_token: user_token
      }
    }
  end

  private

  def set_cbv_flow
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
  end

  # Redirect if the user is attempting connect a previously connected account
  def resume_previous_argyle_account_connection
    item_id = params[:item_id]
    unless item_id.present?
      return render json: { status: :error, message: "Invalid item_id" }, status: :unprocessable_entity
    end

    # If the user ID is not yet set, there is no previous argyle session to resume
    return unless @cbv_flow.argyle_user_id.present?

    # Find any previous Argyle connections to this item
    connected_argyle_accounts = argyle.fetch_accounts_api(user: @cbv_flow.argyle_user_id, item: item_id)["results"]
    return unless connected_argyle_accounts.any?

    # Find the PayrollAccount object (if we have received an accounts.connected webhook)
    argyle_account = connected_argyle_accounts.first
    payroll_account = @cbv_flow.payroll_accounts.find_by(aggregator_account_id: argyle_account["id"])
    return unless payroll_account.present?

    # If we've made it here, there is a previous connection to that item.
    #
    # Redirect to the proper place based on the status of the connection.
    if payroll_account.sync_succeeded? || payroll_account.sync_failed?
      redirect_to cbv_flow_payment_details_path(user: { account_id: payroll_account.aggregator_account_id })
    elsif payroll_account.job_succeeded?("accounts")
      # Sync is in progress, and the user has successfully connected their account.
      redirect_to cbv_flow_synchronizations_path(user: { account_id: payroll_account.aggregator_account_id })
    end
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

  def argyle
    argyle_for(@cbv_flow)
  end
end
