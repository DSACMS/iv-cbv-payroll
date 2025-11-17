require 'rails_helper'

RSpec.describe VolunteeringActivity, type: :model do
  it 'has fields for organization_name, date, and hours' do
    activity = VolunteeringActivity.new(
      organization_name: 'Helping Hands',
      date: Date.new(1990, 12, 10),
      hours: 20
    )

    expect(activity.organization_name).to eq('Helping Hands')
    expect(activity.date).to eq(Date.new(1990, 12, 10))
    expect(activity.hours).to eq(20)
  end
end
