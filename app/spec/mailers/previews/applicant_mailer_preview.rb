# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
class ApplicantMailerPreview < ActionMailer::Preview
  def invitation_email
    ApplicantMailer.with(email_address: "test@example.com", link: "http://example.com").invitation_email
  end

  def caseworker_summary_email
    payments = stub_payments

    cbv_flow = CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi", email_address: "test@example.com")
    ApplicantMailer.with(cbv_flow: cbv_flow, case_number: "12345", payments: payments).caseworker_summary_email
  end
end
