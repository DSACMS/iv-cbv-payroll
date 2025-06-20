require 'rails_helper'

RSpec.describe CbvFlowInvitation, type: :model do
  let(:valid_attributes) do
    attributes_for(:cbv_flow_invitation, :nyc).merge(user: create(:user, client_agency_id: "nyc"), cbv_applicant: create(:cbv_applicant, :nyc))
  end
  let(:invalid_email_no_tld) { "johndoe@gmail" }
  let(:valid_email) { "johndoe@gmail.com" }

  describe "callbacks" do
    context "before_create" do
      let(:current_time) { Time.local(2025, 6, 17, 1, 5, 0) }

      around do |ex|
        Timecop.freeze(current_time, &ex)
      end

      it "sets expires_at based on created_at" do
        invitation = CbvFlowInvitation.new(valid_attributes)
        invitation.save!
        expect(invitation.created_at).to eq(current_time)
        # Saved in the database as UTC, so this will show as 4 hours later than we expect
        expect(invitation.expires_at).to have_attributes(
          hour: 3,
          min: 59,
          sec: 59,
          month: 7,
          day: 2,
        )
      end
    end
  end

  describe "validations" do
    context "for all invitations" do
      context "validates email addresses" do
        context "when email address is valid" do
          valid_email_addresses = %w[johndoe@gmail.com johndoe@example.com.au johndoe@example.com,johndoe@example.com.au]
          valid_email_addresses.each do |email|
            it "#{email} is valid" do
              invitation = CbvFlowInvitation.new(valid_attributes.merge(email_address: email))
              expect(invitation).to be_valid
            end
          end
        end

        context "when email address is invalid" do
          invalid_email_addresses = %w[johndoe@gmail johndoe@gmail..com johndoe@gmail.com..com johndoe@gmail\ .\ com]
          invalid_email_addresses.each do |email|
            it "determines #{email} is invalid" do
              invitation = CbvFlowInvitation.new(valid_attributes.merge(email_address: email))
              expect(invitation).not_to be_valid
              expect(invitation.errors[:email_address]).to include(
                I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.email_address.invalid_format')
              )
            end
          end
        end
      end

      it "requires email_address" do
        invitation = CbvFlowInvitation.new(valid_attributes.merge(email_address: nil))
        expect(invitation).not_to be_valid
        expect(invitation.errors[:email_address]).to include(
          I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.email_address.invalid_format'),
        )
      end

      it "validates email_address format" do
        invitation = CbvFlowInvitation.new(valid_attributes.merge(email_address: "invalid_email"))
        expect(invitation).not_to be_valid
        expect(invitation.errors[:email_address]).to include(
          I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.email_address.invalid_format')
        )
      end
    end
  end

  describe "#expired?" do
    let(:client_agency_id) { "sandbox" }
    let(:invitation_valid_days) { 14 }
    let(:invitation) do
      create(:cbv_flow_invitation, valid_attributes.merge(
        client_agency_id: client_agency_id,
        created_at: invitation_sent_at
      ))
    end
    let(:now) { Time.now }

    before do
      allow(Rails.application.config.client_agencies[client_agency_id])
        .to receive(:invitation_valid_days)
        .and_return(invitation_valid_days)
    end

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    subject { invitation.expired? }

    context "within the validity window" do
      let(:invitation_sent_at)    { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }
      let(:snap_application_date) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }
      let(:now)                   { Time.new(2024, 8, 14, 12, 0, 0, "-04:00") }

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

  describe "#expires_at_local" do
    let(:client_agency_id) { "sandbox" }
    let(:invitation_valid_days) { 14 }
    let(:invitation) do
      create(:cbv_flow_invitation, valid_attributes.merge(
        client_agency_id: client_agency_id,
        created_at: invitation_sent_at
      ))
    end
    let(:invitation_sent_at) { Time.new(2024, 8,  1, 12, 0, 0, "-04:00") }

    before do
      allow(Rails.application.config.client_agencies[client_agency_id])
        .to receive(:invitation_valid_days).and_return(invitation_valid_days)
    end

    it "returns the end of the day the 14th day after the invitation was sent" do
      expect(invitation.expires_at_local).to have_attributes(
        hour: 23,
        min: 59,
        sec: 59,
        month: 8,
        day: 15,
        utc_offset: -14400
      )
    end
  end

  describe "foreign key constraints" do
    context "has an associated user" do
      it "has an associated user email" do
        invitation = create(:cbv_flow_invitation)
        expect(invitation.user.email).to be_a(String)
      end
    end
  end
end
