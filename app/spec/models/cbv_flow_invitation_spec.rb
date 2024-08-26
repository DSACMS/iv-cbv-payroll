require 'rails_helper'

RSpec.describe CbvFlowInvitation, type: :model do
    let(:valid_attributes) do
      {
        email_address: "foo@example.com",
        site_id: "sandbox",
        first_name: "John",
        middle_name: "Doe",
        last_name: "Smith",
        snap_application_date: Date.today
      }
    end

    describe "validations" do
      context "when site_id is 'nyc'" do
        it "requires case_number" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(site_id: 'nyc'))
          invitation.valid?
          expect(invitation.errors[:case_number]).to include("can't be blank")
        end
      end

      context "when site_id is ma" do
        it "requires agency_id_number" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(site_id: 'ma'))
          invitation.valid?
          expect(invitation.errors[:agency_id_number]).to include("can't be blank")
        end

        it "requires beacon_id" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(site_id: 'ma'))
          invitation.valid?
          expect(invitation.errors[:beacon_id]).to include("can't be blank")
        end
      end

      context "when site_id is not 'nyc'" do
        it "does not require client_id_number" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(client_id_number: nil))
          invitation.valid?
          expect(invitation.errors[:client_id_number]).to be_empty
        end
      end

      context "when snap_application_date is not a valid date" do
        it "adds an error" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(snap_application_date: "invalid"))
          invitation.valid?
          expect(invitation.errors[:snap_application_date]).to include("is not a valid date")
        end
      end

      context "requires snap_application_date" do
        it "adds an error" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(snap_application_date: nil))
          invitation.valid?
          expect(invitation.errors[:snap_application_date]).to include("can't be blank")
        end
      end

      context "middle_name is optional" do
        it "is valid" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(middle_name: nil))
          expect(invitation).to be_valid
        end
      end
    end

    describe "#expired?" do
      let(:site_id) { "sandbox" }
      let(:invitation_valid_days) { 14 }
      let(:invitation) do
        create(:cbv_flow_invitation, valid_attributes.merge(
          site_id: site_id,
          created_at: invitation_sent_at
        ))
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

        context "when the invitation was redacted" do
          # This should only happen when redaction is triggered manually, since
          # the automatic redaction should wait until the invitation has
          # already expired.
          before do
            invitation.redact!
          end

          it { is_expected.to eq(true) }
        end
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
        create(:cbv_flow_invitation, valid_attributes.merge(
          site_id: site_id,
          created_at: invitation_sent_at
        ))
      end
      let(:invitation_sent_at) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }

      before do
        allow(Rails.application.config.sites[site_id])
          .to receive(:invitation_valid_days).and_return(invitation_valid_days)
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
