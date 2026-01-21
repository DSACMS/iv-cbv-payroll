require "rails_helper"

RSpec.describe "users.rake" do
  context "users:create_api_token" do
    let(:client_agency_id) { "sandbox" }

    it "creates a user and API key" do
      expect { Rake::Task['users:create_api_token'].execute(client_agency_id: client_agency_id) }
        .to change { User.where(client_agency_id: client_agency_id).count }.by(1)
        .and change(ApiAccessToken, :count).by(1)
    end

    describe "when a user already exists" do
      let!(:user) { create(:user, client_agency_id: client_agency_id, is_service_account: true) }

      it "creates an API key for that user" do
        expect { Rake::Task['users:create_api_token'].execute(client_agency_id: client_agency_id) }
          .to change(User, :count).by(0)
          .and change(ApiAccessToken, :count).by(1)
      end
    end
  end

  context "users:promote_to_service_account" do
    it "promotes a user to a service account" do
      user = create(:user)
      Rake::Task['users:promote_to_service_account'].execute(user_id: user.id.to_s)
      user.reload
      expect(user.is_service_account).to be(true)
      expect(user.api_access_tokens.count).to eq(1)
    end
  end

  context "users:demote_service_account" do
    it "demotes a service account user and removes all access tokens" do
      user = create(:user, :with_access_token, is_service_account: true)
      Rake::Task['users:demote_service_account'].execute(user_id: user.id.to_s)
      user.reload
      expect(user.is_service_account).to be(false)
      expect(user.api_access_tokens.where(deleted_at: nil).count).to eq(0)
    end
  end
end
