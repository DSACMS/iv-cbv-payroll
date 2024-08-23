
# Preview all emails at http://localhost:3000/rails/mailers/caseworker_mailer
class CaseworkerMailerPreview < BaseMailerPreview
  include ViewHelper
  include TestHelpers

  def summary_email
    cbv_flow = FactoryBot.create(:cbv_flow, :with_pinwheel_account)
    payments = stub_post_processed_payments(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    employments = stub_employments(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    incomes = stub_incomes(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    identity = stub_identities(cbv_flow.pinwheel_accounts.first.pinwheel_account_id)
    CaseworkerMailer.with(cbv_flow: cbv_flow, case_number: "12345", payments: payments, employments: employments, incomes: incomes, identity: identity).summary_email
  end
end
