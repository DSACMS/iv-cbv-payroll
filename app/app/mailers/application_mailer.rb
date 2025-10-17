class ApplicationMailer < ActionMailer::Base
  helper :report_view
  default from: "noreply@mail.#{ENV["DOMAIN_NAME"]}"
  layout "mailer"
  after_deliver :track_delivery

  def client_agency_config
    Rails.application.config.client_agencies
  end

  private

  def track_delivery
    event_logger.track(TrackEvent::EmailSent, nil, {
      time: Time.now.to_i,
      mailer: self.class.name,
      action: action_name,
      message_id: mail.message_id,
      locale: I18n.locale,

      # Include a couple attributes that are passed in as params to subclasses,
      # to help with linking metadata without including any PII.
      cbv_applicant_id: params[:cbv_flow]&.cbv_applicant_id || params[:cbv_flow_invitation]&.cbv_applicant_id,
      cbv_flow_id: params[:cbv_flow]&.id,
      invitation_id: params[:cbv_flow_invitation]&.id
    })
  end

  def event_logger
    @event_logger ||= GenericEventTracker.new
  end
end
