require 'rails_helper'

RSpec.describe CbvFlowInvitation, type: :model do
  describe "#expired?" do
    let(:site_id) { "sandbox" }
    let(:invitation_valid_days) { 14 }
    let(:invitation) do
      CbvFlowInvitation.create!(
        email_address: "foo@example.com",
        site_id: site_id,
        created_at: invitation_sent_at
      )
    end
    let(:now) { Time.now }

    before do
      allow(Rails.application.config.sites[site_id])
        .to receive(:invitation_valid_days)
        .and_return(invitation_valid_days)
    end

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    subject { invitation.expired? }

    context "within the validity window" do
      let(:invitation_sent_at) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }
      let(:now)                { Time.new(2024, 8, 14, 12, 0, 0, "-04:00") }

      it { is_expected.to eq(false) }
    end

    context "before 11:59pm ET on the 14th day after the invitation was sent" do
      let(:invitation_sent_at) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }
      let(:now)                { Time.new(2024, 8, 15, 23, 0, 0, "-04:00") }

      it { is_expected.to eq(false) }
    end

    context "after 11:59pm ET on the day of the validity window" do
      let(:invitation_sent_at) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }
      let(:now)                { Time.new(2024, 8, 16,  0, 1, 0, "-04:00") }

      it { is_expected.to eq(true) }
    end
  end

  describe "#expires_at" do
    let(:site_id) { "sandbox" }
    let(:invitation_valid_days) { 14 }
    let(:invitation) do
      CbvFlowInvitation.create!(
        email_address: "foo@example.com",
        site_id: site_id,
        created_at: invitation_sent_at
      )
    end
    let(:invitation_sent_at) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }

    before do
      allow(Rails.application.config.sites[site_id])
        .to receive(:invitation_valid_days)
        .and_return(invitation_valid_days)
    end

    it "returns the end of the day the 14th day after the invitation was sent" do
      expect(invitation.expires_at).to have_attributes(
        hour: 23,
        min: 59,
        sec: 59,
        month: 8,
        day: 15,
        utc_offset: -14400
      )
    end
  end
end
