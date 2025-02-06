require "rails_helper"

RSpec.describe "users.rake" do
  describe "promotes and demotes user service accounts" do
    it "promotes a user to a service account" do
      user = create(:user)
      ENV["id"] = user.id.to_s

      expect {
        Rake::Task['users:promote_to_service_account'].execute
      }.to change { user.reload.api_access_tokens.count }.by(1)

      expect(user.is_service_account).to eq(true)
      expect(user.api_access_tokens.count).to eq(1)
    end

    it "demotes a service account user and removes all access tokens" do
      user = create(:user, :with_access_token, is_service_account: true)
      ENV["id"] = user.id.to_s
      Rake::Task['users:demote_service_account'].execute
      user.reload
      expect(user.is_service_account).to eq(false)
      expect(user.api_access_tokens.where(deleted_at: nil).count).to eq(0)
    end
  end
end
