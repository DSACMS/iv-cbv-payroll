require "rails_helper"

RSpec.describe ApplicantMailer, type: :mailer do
  let(:email) { 'me@email.com' }
  let(:link) { 'www.google.com' }
  let(:mail) { ApplicantMailer.with(email_address: email, link: link).invitation_email }

  it "renders the subject" do
    expect(mail.subject).to eq("Invitation to apply")
  end

  it "renders the receiver email" do
    expect(mail.to).to eq([email])
  end

  it "renders the sender email" do
    expect(mail.from).to eq(["from@example.com"])
  end

  it "renders the body" do
    expect(mail.body.encoded).to match("Thank you for applying")
  end
end
