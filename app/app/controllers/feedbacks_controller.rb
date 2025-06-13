class FeedbacksController < ApplicationController
  include ApplicationHelper

  def show
    cbv_flow = session[:cbv_flow_id] ? CbvFlow.find_by(id: session[:cbv_flow_id]) : nil
    begin
      event_logger.track("ApplicantClickedFeedbackLink", request, {
        timestamp: Time.now.to_i,
        referer: request.referer,
        cbv_flow_id: cbv_flow&.id,
        client_agency_id: cbv_flow&.client_agency_id
      })
    rescue => ex
      raise unless Rails.env.production?
      Rails.logger.error "Unable to track ApplicantClickedFeedbackLink event: #{ex}"
    end
    redirect_to feedback_form_url, allow_other_host: true
  end
end
