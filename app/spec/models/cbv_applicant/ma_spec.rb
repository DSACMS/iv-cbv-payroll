require 'rails_helper'

RSpec.describe CbvApplicant::Ma, type: :model do
  let(:ma_attributes) { attributes_for(:cbv_applicant, :ma) }

  context "user input is invalid" do
    it "requires agency_id_number" do
      applicant = CbvApplicant.new(ma_attributes.without(:agency_id_number))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:agency_id_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/ma.attributes.agency_id_number.invalid_format'),
      )
    end

    it "requires beacon_id" do
      applicant = CbvApplicant.new(ma_attributes.without(:beacon_id))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:beacon_id]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/ma.attributes.beacon_id.invalid_format')
      )
    end

    it "requires beacon_id to have 6 alphanumeric characters" do
      applicant = CbvApplicant.new(ma_attributes.merge(beacon_id: '12345'))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:beacon_id]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/ma.attributes.beacon_id.invalid_format')
      )
    end

    it "validates agency_id_number format" do
      applicant = CbvApplicant.new(ma_attributes.merge(agency_id_number: 'invalid'))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:agency_id_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/ma.attributes.agency_id_number.invalid_format')
      )
    end

    it "does not require client_id_number" do
      applicant = CbvApplicant.new(ma_attributes.merge(client_id_number: nil))
      expect(applicant).to be_valid
      expect(applicant.errors[:client_id_number]).to be_empty
    end
  end
end
