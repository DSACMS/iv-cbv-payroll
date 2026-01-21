require 'rails_helper'

RSpec.describe Identity, type: :model do
  let!(:identity) { create(:identity) }

  it "enforces unique name and DOB combination" do
    expect {
      described_class.create!(
        first_name: identity.first_name,
        last_name: identity.last_name,
        date_of_birth: identity.date_of_birth
      )
    }.to raise_error ActiveRecord::RecordNotUnique
  end

  it "cleans up related models" do
    expect { identity.destroy }
      .to change(ActivityFlow, :count).by(-(identity.activity_flows.count))
  end
end
