# Preview all emails at http://localhost:3000/rails/mailers/caseworker_mailer
class CaseworkerMailerPreview < BaseMailerPreview
  include ReportViewHelper
  include TestHelpers

  def summary_email_la_ldh
    caseworker_user = FactoryBot.create(:user, email: "#{SecureRandom.uuid}@example.com")

    cbv_flow = FactoryBot.create(
      :cbv_flow,
      :with_pinwheel_account,
      :completed,
      client_agency_id: "la_ldh",
      cbv_applicant_attributes: {
        case_number: "LA12345"
      }
    )

    aggregator_report = FactoryBot.build(:pinwheel_report)

    CaseworkerMailer.with(
      email_address: caseworker_user.email,
      cbv_flow: cbv_flow,
      aggregator_report: aggregator_report
    ).summary_email
  end
end
