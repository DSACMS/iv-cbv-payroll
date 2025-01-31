require 'rails_helper'

RSpec.describe User, type: :model do
  it "creates a user with an access token" do
    user = create(:user)
    expect(user.create_api_access_token).to be_present
  end

  it "finds a user by access token" do
    user = create(:user)
    token = user.create_api_access_token
    found_user = User.find_by_access_token(token)
    expect(found_user.id).to eq(user.id)
  end

  it "rejects an access token if it's marked as deleted" do
    user = create(:user)
    token = user.create_api_access_token
    user.api_access_tokens.first.update(deleted_at: Time.now)
    expect(User.find_by_access_token(token)).to be_nil
  end
end
