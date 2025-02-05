require 'rails_helper'

RSpec.describe CbvFlowInvitation, type: :model do
  let(:valid_attributes) do
    attributes_for(:cbv_flow_invitation, :nyc).merge(user: create(:user, client_agency_id: "nyc"))
  end
  let(:invalid_email_no_tld) { "johndoe@gmail" }
  let(:valid_email) { "johndoe@gmail.com" }

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

      it "requires snap_application_date" do
        invitation = CbvFlowInvitation.new(valid_attributes.merge(snap_application_date: nil))
        expect(invitation).not_to be_valid
        expect(invitation.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.snap_application_date.nyc_invalid_date'),
        )
      end

      it "validates snap_application_date is not in the future" do
        invitation = CbvFlowInvitation.new(valid_attributes.merge(snap_application_date: Date.tomorrow))
        expect(invitation).not_to be_valid
        expect(invitation.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.snap_application_date.nyc_invalid_date')
        )
      end

      it "parses snap_application_date strings correctly" do
        invitation = CbvFlowInvitation.new(valid_attributes.merge(snap_application_date: "08/15/2023"))
        expect(invitation).not_to be_valid
        expect(invitation.snap_application_date).to eq(Date.new(2023, 8, 15))
      end

      it "adds an error when snap_application_date is not a valid date" do
        invitation = CbvFlowInvitation.new(valid_attributes.merge(snap_application_date: "invalid"))
        expect(invitation).not_to be_valid
        expect(invitation.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.snap_application_date.nyc_invalid_date')
        )
      end

      it "allows middle_name to be optional" do
        invitation = create(:cbv_flow_invitation, middle_name: nil)
        expect(invitation).to be_valid
      end
    end

    context "when client_agency_id is 'nyc'" do
      let(:nyc_attributes) { valid_attributes.merge(client_agency_id: 'nyc', user: create(:user, client_agency_id: "nyc")) }

      context "user input is valid" do
        it "formats a 9-character case number with leading zeros" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(case_number: '12345678A'))
          expect(invitation).to be_valid
          expect(invitation.case_number).to eq('00012345678A')
        end

        it "converts case number to uppercase" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(case_number: '12345678a'))
          expect(invitation).to be_valid
          expect(invitation.case_number).to eq('00012345678A')
        end

        it "validates snap_application_date is not older than 30 days" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(snap_application_date: 31.days.ago))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:snap_application_date]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.snap_application_date.nyc_invalid_date')
          )
        end
      end

      context "user input is invalid" do
        it "requires case_number" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(case_number: nil))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:case_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.case_number.invalid_format'),
          )
        end

        it "validates invalid case_number format" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(case_number: 'invalid'))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:case_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.case_number.invalid_format')
          )
        end

        it "checks that a shorter case number is invalid" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(case_number: '123A'))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:case_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.case_number.invalid_format')
          )
        end

        it "validates an invalid 11 char string" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(case_number: '1234567890A'))
          expect(invitation).not_to be_valid
          expect(invitation.case_number).to eq('1234567890A')
        end

        it "validates client_id_number format when present" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(client_id_number: 'invalid'))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:client_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.client_id_number.invalid_format')
          )
        end

        it "requires valid snap_application_date" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(snap_application_date: "invalid"))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:snap_application_date]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.snap_application_date.nyc_invalid_date')
          )
        end

        it "requires client_id_number" do
          invitation = CbvFlowInvitation.new(nyc_attributes.merge(client_id_number: nil))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:client_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.client_id_number.invalid_format')
          )
        end
      end
    end

    context "when client_agency_id is 'ma'" do
      let(:ma_attributes) { valid_attributes.merge(client_agency_id: 'ma') }

      context "user input is invalid" do
        it "requires agency_id_number" do
          invitation = CbvFlowInvitation.new(ma_attributes)
          expect(invitation).not_to be_valid
          expect(invitation.errors[:agency_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.agency_id_number.invalid_format'),
          )
        end

        it "requires beacon_id" do
          invitation = CbvFlowInvitation.new(ma_attributes)
          expect(invitation).not_to be_valid
          expect(invitation.errors[:beacon_id]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.beacon_id.invalid_format')
          )
        end

        it "requires beacon_id to have 6 alphanumeric characters" do
          invitation = CbvFlowInvitation.new(ma_attributes.merge(beacon_id: '12345'))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:beacon_id]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.beacon_id.invalid_format')
          )
        end

        it "validates agency_id_number format" do
          invitation = CbvFlowInvitation.new(ma_attributes.merge(agency_id_number: 'invalid'))
          expect(invitation).not_to be_valid
          expect(invitation.errors[:agency_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_flow_invitation.attributes.agency_id_number.invalid_format')
          )
        end

        it "does not require client_id_number" do
          invitation = CbvFlowInvitation.new(valid_attributes.merge(client_id_number: nil, client_agency_id: "ma"))
          expect(invitation).to be_valid
          expect(invitation.errors[:client_id_number]).to be_empty
        end
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

  describe "foreign key constraints" do
    context "has an associated user" do
      it "has an associated user email" do
        invitation = create(:cbv_flow_invitation)
        expect(invitation.user.email).to be_a(String)
      end
    end
  end
end
