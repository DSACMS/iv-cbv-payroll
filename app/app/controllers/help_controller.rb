class HelpController < Cbv::BaseController
  layout "help"

  def index
    @title = t("help.index.title")
  end

  def show
    @help_topic = params[:topic].gsub("-", "_")
    @title = t("help.show.#{@help_topic}.title")

    event_logger.track("ApplicantViewedHelpTopic", request, {
      topic: @help_topic,
      cbv_flow_id: @cbv_flow&.id,
      invitation_id: @cbv_flow&.cbv_flow_invitation_id,
      site_id: @cbv_flow&.site_id,
      flow_started_seconds_ago: (Time.now - cbv_flow.created_at).to_i,
      language: I18n.locale
    }.compact)
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantViewedHelpTopic): #{ex}"
  end
end
