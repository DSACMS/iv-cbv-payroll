require 'rails_helper'
require_relative "../cbv_applicant_spec.rb"

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

  it "redacts all sensitive PII fields" do
    applicant = CbvApplicant.create(ma_attributes)
    applicant.redact!
    expect(applicant).to have_attributes(
      first_name: "REDACTED",
      middle_name: "REDACTED",
      last_name: "REDACTED",
      agency_id_number: "REDACTED",
      beacon_id: "REDACTED",
    )
  end
end
