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
      language: get_requested_locale(request)
    )
    token = token_response["data"]["token"]

    render json: { status: :ok, token: token }
  end

  private

  def get_requested_locale(request)
    locale_sources = [
      params[:locale],
      request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first
    ]

    locale_sources.compact.find { |locale| I18n.available_locales.map(&:to_s).include?(locale) } || I18n.default_locale
  end
  def token_params
    params.require(:pinwheel).permit(:response_type, :id)
  end

  def track_event
    NewRelicEventTracker.track("ApplicantBeganLinkingEmployer", {
      cbv_flow_id: @cbv_flow.id,
      response_type: token_params[:response_type]
    })
  rescue => ex
    Rails.logger.error "Unable to track NewRelic event (ApplicantBeganLinkingEmployer): #{ex}"
  end
end
