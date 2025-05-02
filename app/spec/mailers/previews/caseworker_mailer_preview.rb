
# Preview all emails at http://localhost:3000/rails/mailers/caseworker_mailer
class CaseworkerMailerPreview < BaseMailerPreview
  include ReportViewHelper
  include TestHelpers

  def summary_email
    caseworker_user = FactoryBot.create(:user, email: "#{SecureRandom.uuid}@example.com")
    invitation = FactoryBot.create(:cbv_flow_invitation, :nyc, user: caseworker_user)
    cbv_flow = FactoryBot.create(
      :cbv_flow,
      :with_pinwheel_account,
      :completed,
      cbv_flow_invitation: invitation
    )

    aggregator_report = FactoryBot.build(:pinwheel_report)

    CaseworkerMailer.with(
      email_address: invitation.email_address,
      cbv_flow: cbv_flow,
      case_number: "12345",
      aggregator_report: aggregator_report
    ).summary_email
  end
end
