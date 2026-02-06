class FeedbacksController < ApplicationController
  include ApplicationHelper

  def show
    cbv_flow = session[:flow_id] ? CbvFlow.find_by(id: session[:flow_id]) : nil
    event_name = params[:form] == "survey" ? "ApplicantClickedFeedbackSurveyLink" : "ApplicantClickedFeedbackLink"
    attributes = {
      referer: params[:referer],
      cbv_flow_id: cbv_flow&.id,
      cbv_applicant_id: cbv_flow&.cbv_applicant_id,
      client_agency_id: cbv_flow&.cbv_applicant&.client_agency_id
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
      feedback_form_url
    end
  end
end
