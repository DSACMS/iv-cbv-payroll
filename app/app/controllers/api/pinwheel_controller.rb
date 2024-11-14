class Api::PinwheelController < ApplicationController
  after_action :track_event, only: :create_token

  # run the token here with the included employer/payroll provider id
  def create_token
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])
    pinwheel = pinwheel_for(@cbv_flow)
    token_response = pinwheel.create_link_token(
      response_type: token_params[:response_type],
      id: token_params[:id],
      end_user_id: @cbv_flow.pinwheel_end_user_id,
      language: token_params[:locale]
    )
    token = token_response["data"]["token"]

    render json: { status: :ok, token: token }
  end

  def user_action
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])

    case user_action_params[:response_type]
    when 'platform'
      track_selected_payroll_platform
    when 'employer'
      track_selected_app_employer
    end

    render json: { status: :ok }
  rescue => ex
    Rails.logger.error "Unable to process user action: #{ex}"
    render json: { status: :error }, status: :unprocessable_entity
  end

  private

  def user_action_params
    params.require(:pinwheel).permit(:response_type, :id, :name, :locale)
  end

  def token_params
    params.require(:pinwheel).permit(:response_type, :id, :locale)
  end

  def track_selected_payroll_platform
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])

    NewRelicEventTracker.track("ApplicantSelectedPopularPayrollPlatform", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      payroll_platform_id: user_action_params[:id],
      payroll_platform_name: user_action_params[:name],
      locale: user_action_params[:locale]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantSelectedPopularPayrollPlatform): #{ex}"
  end

  def track_selected_app_employer
    @cbv_flow = CbvFlow.find(session[:cbv_flow_id])

    NewRelicEventTracker.track("ApplicantSelectedPopularAppEmployer", {
      timestamp: Time.now.to_i,
      cbv_flow_id: @cbv_flow.id,
      employer_id: user_action_params[:id],
      employer_name: user_action_params[:name],
      locale: user_action_params[:locale]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantSelectedPopularAppEmployer): #{ex}"
  end

  def track_event
    NewRelicEventTracker.track("ApplicantBeganLinkingEmployer", {
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      response_type: token_params[:response_type]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantBeganLinkingEmployer): #{ex}"
  end
end
