class FeedbacksController < ApplicationController
  include ApplicationHelper

  def show
    cbv_flow = session[:flow_id] ? CbvFlow.find_by(id: session[:flow_id]) : nil
    @client_agency_id = cbv_flow&.cbv_applicant&.client_agency_id
    event_name = params[:form] == "survey" ? "ApplicantClickedFeedbackSurveyLink" : "ApplicantClickedFeedbackLink"
    attributes = {
      referer: params[:referer],
      cbv_flow_id: cbv_flow&.id,
      cbv_applicant_id: cbv_flow&.cbv_applicant_id,
      client_agency_id: @client_agency_id
    }

    event_logger.track(event_name, request, {
      time: Time.now.to_i,
      **attributes
    })

    redirect_to redirect_path, allow_other_host: true
  end

  private

  def redirect_path
    if params[:form] == "survey"
      survey_form_url
    else
      append_prefill_params(feedback_form_url)
    end
  end

  def append_prefill_params(url)
    device_id = cookies.permanent.signed[:device_id]
    return url if device_id.blank?

    identifier = [ @client_agency_id, device_id ].compact.join("/")

    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || "")
    params << [ "usp", "pp_url" ]
    params << [ ApplicationHelper::FEEDBACK_FORM_DEVICE_ID_ENTRY, identifier ]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
