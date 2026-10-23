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

  describe "#expired?" do
    subject { invitation.expired? }

    let(:invitation) { create(:activity_flow_invitation, created_at: invitation_sent_at) }
    let(:invitation_sent_at) { Time.new(2024, 8, 1, 12, 0, 0, "-04:00") }

    before do
      allow(Rails.application.config.client_agencies["sandbox"])
        .to receive(:invitation_valid_days).and_return(14)
    end

    around do |example|
      Timecop.freeze(now, &example)
    end

    context "within the validity window" do
      let(:now) { Time.new(2024, 8, 14, 12, 0, 0, "-04:00") }

      it { is_expected.to be(false) }
    end

    context "without an expiration" do
      let(:now) { Time.new(2024, 8, 14, 12, 0, 0, "-04:00") }

      before { invitation.update_columns(expires_at: nil) }

      it { is_expected.to be(true) }
    end

    context "at 11:59pm ET on the 14th day after the invitation was sent" do
      let(:now) { Time.new(2024, 8, 15, 23, 59, 59, "-04:00") }

      it { is_expected.to be(false) }
    end

    context "after the end of the 14th day in Eastern Time" do
      let(:now) { Time.new(2024, 8, 16, 0, 0, 0, "-04:00") }

      it { is_expected.to be(true) }
    end
  end

  describe "#used?" do
    let(:invitation) { create(:activity_flow_invitation) }
    let(:agency) { Rails.application.config.client_agencies[invitation.client_agency_id] }

    before { allow(agency).to receive(:allow_activity_invitation_reuse).and_return(false) }

    it "does not consume an invitation before submission" do
      create(:activity_flow, activity_flow_invitation: invitation)

      expect(invitation).not_to be_used
    end

    context "with a completed report awaiting delivery" do
      before { create(:activity_flow, activity_flow_invitation: invitation, completed_at: Time.current) }

      it "treats the invitation as used" do
        expect(invitation).to be_used
      end

      context "when reuse is allowed" do
        before { allow(agency).to receive(:allow_activity_invitation_reuse).and_return(true) }

        it "allows the invitation to be reused" do
          expect(invitation).not_to be_used
        end
      end
    end

    context "for Employment" do
      let(:invitation) { create(:activity_flow_invitation, employment_focused: true) }

      before { create(:activity_flow, activity_flow_invitation: invitation, completed_at: Time.current, employment_focused: true) }

      it "applies the same single-use policy" do
        expect(invitation).to be_used
      end
    end
  end

  describe "#expires_at" do
    subject(:expires_at) { invitation.reload.expires_at.in_time_zone("America/New_York") }

    let(:invitation) { create(:activity_flow_invitation, created_at: invitation_sent_at) }
    let(:invitation_sent_at) { Time.new(2024, 8, 1, 12, 0, 0, "-04:00") }
    let(:invitation_valid_days) { 14 }

    before do
      allow(Rails.application.config.client_agencies["sandbox"])
        .to receive(:invitation_valid_days).and_return(invitation_valid_days)
    end

    it "persists the end of the 14th day after creation in Eastern Time" do
      expect(expires_at).to have_attributes(
        year: 2024, month: 8, day: 15, hour: 23, min: 59, sec: 59, utc_offset: -14400
      )
    end

    context "with a different agency validity window" do
      let(:invitation_valid_days) { 7 }

      it "uses the configured number of days" do
        expect(expires_at).to have_attributes(month: 8, day: 8, hour: 23, min: 59, sec: 59)
      end
    end

    context "when the creation date differs between UTC and Eastern Time" do
      let(:invitation_sent_at) { Time.utc(2024, 8, 2, 2, 0, 0) }

      it "calculates from the Eastern Time creation date" do
        expect(expires_at).to have_attributes(month: 8, day: 15, hour: 23, min: 59, sec: 59)
      end
    end

    context "when daylight saving time ends during the validity window" do
      let(:invitation_sent_at) { Time.new(2024, 10, 25, 12, 0, 0, "-04:00") }

      it "still expires at the end of the day in Eastern Time" do
        expect(expires_at).to have_attributes(month: 11, day: 8, hour: 23, min: 59, sec: 59, utc_offset: -18000)
      end
    end

    context "with an explicit expiration" do
      let(:explicit_expiration) { Time.utc(2024, 8, 10, 12, 0, 0) }
      let(:invitation) { create(:activity_flow_invitation, expires_at: explicit_expiration) }

      it "preserves the explicit expiration" do
        expect(expires_at).to eq(explicit_expiration)
      end
    end

    it "does not recalculate the expiration on update" do
      original_expiration = invitation.expires_at
      invitation.update!(created_at: invitation_sent_at + 1.day)

      expect(invitation.reload.expires_at).to eq(original_expiration)
    end
  end

  describe "#to_url" do
    it "generates a URL with the auth token" do
      invitation = create(:activity_flow_invitation)

      expect(invitation.to_url).to include(invitation.auth_token)
      expect(invitation.to_url).to include("activities/start")
    end
  end

  describe "#employment_focused" do
    it "defaults to false" do
      invitation = create(:activity_flow_invitation)

      expect(invitation.employment_focused).to be(false)
    end
  end
end
