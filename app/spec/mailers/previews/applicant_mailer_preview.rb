# Preview all emails at http://localhost:3000/rails/mailers/applicant_mailer
class ApplicantMailerPreview < BaseMailerPreview
  include ReportViewHelper

  private
  def unique_user
    FactoryBot.create(:user, email: "#{SecureRandom.uuid}@example.com")
  end
end
