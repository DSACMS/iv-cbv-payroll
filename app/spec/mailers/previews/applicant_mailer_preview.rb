# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
require Rails.root.join('spec/support/test_helpers')
class ApplicantMailerPreview < ActionMailer::Preview
  include ViewHelper
  include TestHelpers # in order to use stub_payments

  def invitation_email
    ApplicantMailer.with(email_address: "test@example.com", link: "http://example.com").invitation_email
  end
end
