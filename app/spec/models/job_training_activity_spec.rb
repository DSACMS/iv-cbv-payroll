require 'rails_helper'

RSpec.describe JobTrainingActivity, type: :model do
  it 'stores program name, organization address, and hours' do
    flow = create(:activity_flow)

    activity = JobTrainingActivity.new(
      activity_flow: flow,
      program_name: 'Resume Workshop',
      organization_address: '123 Main St, Baton Rouge, LA',
      hours: 12
    )

    expect(activity).to be_valid
    expect(activity.program_name).to eq('Resume Workshop')
    expect(activity.organization_address).to eq('123 Main St, Baton Rouge, LA')
    expect(activity.hours).to eq(12)
  end
end
