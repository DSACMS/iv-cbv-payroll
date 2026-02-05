class HelpController < ApplicationController
  layout "help"
  helper_method :current_agency

  def index
    @title = t("help.index.title")
    render layout: false
  end

  def show
    @help_topic = params[:topic].gsub("-", "_")
    @title = t("help.show.#{@help_topic}.title")

    cbv_flow = session[:flow_id] ? CbvFlow.find_by(id: session[:flow_id]) : nil

    event_logger.track(TrackEvent::ApplicantViewedHelpTopic, request, {
      time: Time.now.to_i,
      topic: @help_topic,
      cbv_applicant_id: cbv_flow&.cbv_applicant_id,
      cbv_flow_id: session[:flow_id],

      invitation_id: cbv_flow&.cbv_flow_invitation_id,
      client_agency_id: current_agency&.id,
      flow_started_seconds_ago: cbv_flow ? (Time.now - cbv_flow.created_at).to_i : nil,
      locale: I18n.locale
    })

    render layout: false if turbo_frame_request?
  end

  private

  def current_agency
    @current_agency ||= find_site_from_flow || agency_config[params[:client_agency_id]]
  end

  def find_site_from_flow
    return unless session[:flow_id]

    cbv_flow = CbvFlow.find_by(id: session[:flow_id])
    agency_config[cbv_flow.cbv_applicant.client_agency_id] if cbv_flow
  end
end
