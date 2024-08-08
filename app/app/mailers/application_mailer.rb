class ApplicationMailer < ActionMailer::Base
  default from: "noreply@mail.#{ENV["DOMAIN_NAME"]}"
  layout "mailer"

  def site_config
    Rails.application.config.sites
  end
end
