require 'rails_helper'

RSpec.describe Identity, type: :model do
  it "enforces unique name and DOB combination" do
    identity = create(:identity)

    expect {
      Identity.create!(
        first_name: identity.first_name,
        last_name: identity.last_name,
        date_of_birth: identity.date_of_birth
      )
    }.to raise_error ActiveRecord::RecordNotUnique
  end
end
