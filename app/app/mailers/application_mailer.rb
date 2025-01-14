class ApplicationMailer < ActionMailer::Base
  default from: "noreply@mail.#{ENV["DOMAIN_NAME"]}"
  layout "mailer"
  after_deliver :track_delivery

  def site_config
    Rails.application.config.sites
  end

  private

  def track_delivery
    event_logger.track("EmailSent", nil, {
      mailer: self.class.name,
      action: action_name,
      message_id: mail.message_id,
      locale: I18n.locale,

      # Include a couple attributes that are passed in as params to subclasses,
      # to help with linking metadata without including any PII.
      cbv_flow_id: params[:cbv_flow]&.id,
      invitation_id: params[:cbv_flow_invitation]&.id
    })
  end

  def event_logger
    if params[:existing_event_logger].present?
      @event_logger = params[:existing_event_logger]
    else
      @event_logger ||= GenericEventTracker.for_request(nil)
    end
  end
end
