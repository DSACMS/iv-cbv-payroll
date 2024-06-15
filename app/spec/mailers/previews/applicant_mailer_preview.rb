# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
class ApplicantMailerPreview < ActionMailer::Preview
  def invitation_email
    ApplicantMailer.with(email_address: "test@example.com", link: "http://example.com").invitation_email
  end

  def caseworker_summary_email
    payments = 5.times.map do |i|
      {
        employer: "Employer #{i + 1}",
        amount: (100 * (i + 1)),
        start: Date.today.beginning_of_month + i.months,
        end: Date.today.end_of_month + i.months,
        hours: (40 * (i + 1)),
        rate: (10 + i)
      }
    end

    cbv_flow = CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi")
    ApplicantMailer.with(cbv_flow: cbv_flow, email_address: "test@example.com", case_number: "12345", payments: payments).caseworker_summary_email
  end
end
