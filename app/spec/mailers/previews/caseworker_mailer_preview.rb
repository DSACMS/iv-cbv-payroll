# Preview all emails at http://localhost:3000/rails/mailers/caseworker_mailer
class CaseworkerMailerPreview < ActionMailer::Preview
  include ViewHelper
  include TestHelpers

  def summary_email
    payments =  stub_payments
    cbv_flow = CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi")
    CaseworkerMailer.with(cbv_flow: cbv_flow, case_number: "12345", payments: payments).summary_email
  end
end
