class ApplicationMailer < ActionMailer::Base
  default from: "noreply@mail.#{ENV["DOMAIN_NAME"]}"
  layout "mailer"
end
