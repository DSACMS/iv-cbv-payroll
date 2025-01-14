
# Preview all emails at http://localhost:3000/rails/mailers/caseworker_mailer
class CaseworkerMailerPreview < BaseMailerPreview
  include ViewHelper
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
    payments = stub_post_processed_payments(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    employments = stub_employments(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    incomes = stub_incomes(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    identities = stub_identities(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)

    CaseworkerMailer.with(
      email_address: invitation.email_address,
      cbv_flow: cbv_flow,
      case_number: "12345",
      payments: payments,
      employments: employments,
      incomes: incomes,
      identities: identities,
      existing_event_logger: event_logger
    ).summary_email
  end
end
