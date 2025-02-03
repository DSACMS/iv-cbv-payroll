class HelpController < Cbv::BaseController
  layout "help"
  skip_before_action :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view

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
      flow_started_seconds_ago: @cbv_flow ? (Time.now - @cbv_flow.created_at).to_i : nil,
      language: I18n.locale
    }.compact)
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantViewedHelpTopic): #{ex}"
  end
end
