require 'rails_helper'

RSpec.describe ActivityFlowInvitation, type: :model do
  it "has many activity flows" do
    invitation = create(:activity_flow_invitation)
    flow1 = create(:activity_flow, activity_flow_invitation: invitation)
    flow2 = create(:activity_flow, activity_flow_invitation: invitation)

    expect(invitation.activity_flows).to contain_exactly(flow1, flow2)
  end

  it "generates a secure token on create" do
    invitation = create(:activity_flow_invitation)

    expect(invitation.auth_token).to be_present
    expect(invitation.auth_token.length).to eq(10)
  end

  describe "#to_url" do
    it "generates a URL with the auth token" do
      invitation = create(:activity_flow_invitation)

      expect(invitation.to_url).to include(invitation.auth_token)
      expect(invitation.to_url).to include("activities/start")
    end
  end

  describe "month-in-window validation" do
    let(:in_window_date) { ActivityFlow.expected_reporting_window_range("sandbox").end.iso8601 }
    let(:out_of_window_date) { (Date.current + 60.days).iso8601 }

    it "is valid when months fall within the expected reporting window" do
      invitation = build(:activity_flow_invitation)

      expect(invitation).to be_valid
    end
  end
end
