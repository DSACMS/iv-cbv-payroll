class FeedbacksController < ApplicationController
  include ApplicationHelper

  def show
    cbv_flow = session[:cbv_flow_id] ? CbvFlow.find_by(id: session[:cbv_flow_id]) : nil

    track_feedback_event(cbv_flow)

    redirect_to redirect_path, allow_other_host: true
  end

  private

  def redirect_path
    if params[:source] == "success_page"
      survey_form_url
    else
      feedback_form_url
    end
  end

  def track_feedback_event(cbv_flow)
    event_name = if params[:source] == "success_page"
                   "ApplicantClickedSurveyLinkOnSuccessPage"
                 else
                   "ApplicantClickedFeedbackLink"
                 end

    event_logger.track(event_name, request, {
      timestamp: Time.now.to_i,
      referer: params[:referer],
      cbv_flow_id: cbv_flow&.id,
      cbv_applicant_id: cbv_flow&.cbv_applicant_id,
      client_agency_id: cbv_flow&.client_agency_id,
      source: params[:source]
    })
  rescue => ex
    raise unless Rails.env.production?
    Rails.logger.error "Unable to track feedback event: #{ex}"
  end
end
