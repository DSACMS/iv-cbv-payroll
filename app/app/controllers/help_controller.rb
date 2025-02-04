class HelpController < ApplicationController
  layout "help"
  helper_method :current_site

  def index
    @title = t("help.index.title")
  end

  def show
    @help_topic = params[:topic].gsub("-", "_")
    @title = t("help.show.#{@help_topic}.title")

    cbv_flow = session[:cbv_flow_id] ? CbvFlow.find_by(id: session[:cbv_flow_id]) : nil

    event_logger.track("ApplicantViewedHelpTopic", request, {
      topic: @help_topic,
      cbv_flow_id: session[:cbv_flow_id],
      invitation_id: cbv_flow&.cbv_flow_invitation_id,
      site_id: current_site&.id,
      flow_started_seconds_ago: cbv_flow ? (Time.now - cbv_flow.created_at).to_i : nil,
      language: I18n.locale
    }.compact)
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantViewedHelpTopic): #{ex}"
  end

  private

  def current_site
    @current_site ||= find_site_from_flow || site_config[params[:site_id]]
  end

  def find_site_from_flow
    return unless session[:cbv_flow_id]
    
    cbv_flow = CbvFlow.find_by(id: session[:cbv_flow_id])
    site_config[cbv_flow.site_id] if cbv_flow
  end
end
