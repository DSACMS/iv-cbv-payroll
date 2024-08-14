# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
require Rails.root.join('spec/support/test_helpers')
class ApplicantMailerPreview < ActionMailer::Preview
  include ViewHelper
  include TestHelpers

  def invitation_email
    ApplicantMailer.with(
      cbv_flow_invitation: create(:cbv_flow_invitation)
    ).invitation_email
  end
end
