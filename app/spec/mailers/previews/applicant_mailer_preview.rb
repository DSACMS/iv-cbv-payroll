# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
class ApplicantMailerPreview < ActionMailer::Preview
  def invitation_email
    ApplicantMailer.with(email_address: "test@example.com", link: "http://example.com").invitation_email
  end
end
