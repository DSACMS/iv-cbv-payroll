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
          I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.nyc_invalid_date'),
        )
      end

      it "validates snap_application_date is not in the future" do
        applicant = CbvApplicant.new(valid_attributes.merge(snap_application_date: Date.tomorrow))
        expect(applicant).not_to be_valid
        expect(applicant.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.nyc_invalid_date')
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
          I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.nyc_invalid_date')
        )
      end
    end
  end
end
