require 'rails_helper'

RSpec.describe CbvApplicant, type: :model do
  describe '.create_from_invitation' do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

    it 'creates a new CbvApplicant with attributes from cbv_flow_invitation' do
      cbv_applicant = CbvApplicant.create_from_invitation(cbv_flow_invitation)
      expect(cbv_applicant).to be_persisted
      expect(cbv_applicant.case_number).to eq(cbv_flow_invitation.case_number)
      expect(cbv_applicant.first_name).to eq(cbv_flow_invitation.first_name)
      expect(cbv_applicant.middle_name).to eq(cbv_flow_invitation.middle_name)
      expect(cbv_applicant.last_name).to eq(cbv_flow_invitation.last_name)
      expect(cbv_applicant.agency_id_number).to eq(cbv_flow_invitation.agency_id_number)
      expect(cbv_applicant.client_id_number).to eq(cbv_flow_invitation.client_id_number)
      expect(cbv_applicant.snap_application_date).to eq(cbv_flow_invitation.snap_application_date)
      expect(cbv_applicant.beacon_id).to eq(cbv_flow_invitation.beacon_id)
    end

    it 'associates the CbvApplicant with the CbvFlowInvitation' do
      cbv_applicant = CbvApplicant.create_from_invitation(cbv_flow_invitation)
      cbv_flow_invitation.reload
      expect(cbv_flow_invitation.cbv_applicant).to eq(cbv_applicant)
    end
  end

  describe "validations" do
    let(:valid_attributes) { attributes_for(:cbv_applicant, :nyc) }

    it "allows middle_name to be optional" do
      applicant = create(:cbv_applicant, middle_name: nil)
      expect(applicant).to be_valid
    end

    describe "snap_application_date" do
      it "requires snap_application_date" do
        applicant = CbvApplicant.new(valid_attributes.merge(snap_application_date: nil))
        expect(applicant).not_to be_valid
        expect(applicant.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_applicant.attributes.snap_application_date.nyc_invalid_date'),
        )
      end

      it "validates snap_application_date is not in the future" do
        applicant = CbvApplicant.new(valid_attributes.merge(snap_application_date: Date.tomorrow))
        expect(applicant).not_to be_valid
        expect(applicant.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_applicant.attributes.snap_application_date.nyc_invalid_date')
        )
      end

      it "parses snap_application_date strings correctly" do
        applicant = CbvApplicant.new(valid_attributes.merge(snap_application_date: "08/15/2023"))
        expect(applicant).not_to be_valid
        expect(applicant.snap_application_date).to eq(Date.new(2023, 8, 15))
      end

      it "adds an error when snap_application_date is not a valid date" do
        applicant = CbvApplicant.new(valid_attributes.merge(snap_application_date: "invalid"))
        expect(applicant).not_to be_valid
        expect(applicant.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_applicant.attributes.snap_application_date.nyc_invalid_date')
        )
      end
    end

    context "when client_agency_id is 'nyc'" do
      let(:nyc_attributes) { valid_attributes.merge(client_agency_id: 'nyc') }

      context "user input is valid" do
        it "formats a 9-character case number with leading zeros" do
          applicant = CbvApplicant.new(nyc_attributes.merge(case_number: '12345678A'))
          expect(applicant).to be_valid
          expect(applicant.case_number).to eq('00012345678A')
        end

        it "converts case number to uppercase" do
          applicant = CbvApplicant.new(nyc_attributes.merge(case_number: '12345678a'))
          expect(applicant).to be_valid
          expect(applicant.case_number).to eq('00012345678A')
        end

        it "validates snap_application_date is not older than 30 days" do
          applicant = CbvApplicant.new(nyc_attributes.merge(snap_application_date: 31.days.ago))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:snap_application_date]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.snap_application_date.nyc_invalid_date')
          )
        end
      end

      context "user input is invalid" do
        it "requires case_number" do
          applicant = CbvApplicant.new(nyc_attributes.merge(case_number: nil))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:case_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.case_number.invalid_format'),
          )
        end

        it "validates invalid case_number format" do
          applicant = CbvApplicant.new(nyc_attributes.merge(case_number: 'invalid'))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:case_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.case_number.invalid_format')
          )
        end

        it "checks that a shorter case number is invalid" do
          applicant = CbvApplicant.new(nyc_attributes.merge(case_number: '123A'))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:case_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.case_number.invalid_format')
          )
        end

        it "validates an invalid 11 char string" do
          applicant = CbvApplicant.new(nyc_attributes.merge(case_number: '1234567890A'))
          expect(applicant).not_to be_valid
          expect(applicant.case_number).to eq('1234567890A')
        end

        it "validates client_id_number format when present" do
          applicant = CbvApplicant.new(nyc_attributes.merge(client_id_number: 'invalid'))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:client_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.client_id_number.invalid_format')
          )
        end

        it "requires valid snap_application_date" do
          applicant = CbvApplicant.new(nyc_attributes.merge(snap_application_date: "invalid"))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:snap_application_date]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.snap_application_date.nyc_invalid_date')
          )
        end

        it "requires client_id_number" do
          applicant = CbvApplicant.new(nyc_attributes.merge(client_id_number: nil))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:client_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.client_id_number.invalid_format')
          )
        end
      end
    end

    context "when client_agency_id is 'ma'" do
      let(:ma_attributes) { valid_attributes.merge(client_agency_id: 'ma') }

      context "user input is invalid" do
        it "requires agency_id_number" do
          applicant = CbvApplicant.new(ma_attributes)
          expect(applicant).not_to be_valid
          expect(applicant.errors[:agency_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.agency_id_number.invalid_format'),
          )
        end

        it "requires beacon_id" do
          applicant = CbvApplicant.new(ma_attributes)
          expect(applicant).not_to be_valid
          expect(applicant.errors[:beacon_id]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.beacon_id.invalid_format')
          )
        end

        it "requires beacon_id to have 6 alphanumeric characters" do
          applicant = CbvApplicant.new(ma_attributes.merge(beacon_id: '12345'))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:beacon_id]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.beacon_id.invalid_format')
          )
        end

        it "validates agency_id_number format" do
          applicant = CbvApplicant.new(ma_attributes.merge(agency_id_number: 'invalid'))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:agency_id_number]).to include(
            I18n.t('activerecord.errors.models.cbv_applicant.attributes.agency_id_number.invalid_format')
          )
        end

        it "does not require client_id_number" do
          applicant = CbvApplicant.new(valid_attributes.merge(client_id_number: nil, client_agency_id: "ma"))
          expect(applicant).not_to be_valid
          expect(applicant.errors[:client_id_number]).to be_empty
        end
      end
    end
  end
end
