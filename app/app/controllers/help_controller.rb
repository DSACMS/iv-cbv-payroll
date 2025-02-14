class HelpController < ApplicationController
  include CbvEventTracking
  layout "help"
  helper_method :current_agency

  def index
    @title = t("help.index.title")
  end

  def show
    @help_topic = params[:topic].gsub("-", "_")
    @title = t("help.show.#{@help_topic}.title")

    track_event(
      "ApplicantViewedHelpTopic",
      request,
      {
        topic: params[:topic],
        cbv_applicant_id: current_cbv_flow&.cbv_applicant_id
      }
    )
  end

  protected

  def current_agency
    @current_agency ||= find_site_from_flow || agency_config[params[:client_agency_id]]
  end

  private

  def find_site_from_flow
    return unless current_cbv_flow
    agency_config[current_cbv_flow.client_agency_id]
  end
end
