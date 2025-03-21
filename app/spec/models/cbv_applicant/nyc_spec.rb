require 'rails_helper'

RSpec.describe CbvApplicant::Nyc, type: :model do
  let(:nyc_attributes) { attributes_for(:cbv_applicant, :nyc) }

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
      applicant = CbvApplicant.new(nyc_attributes)
      applicant.snap_application_date = 31.days.ago
      expect(applicant).not_to be_valid
      expect(applicant.errors[:snap_application_date]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.invalid_date')
      )
    end
  end

  context "user input is invalid" do
    it "requires case_number" do
      applicant = CbvApplicant.new(nyc_attributes.merge(case_number: nil))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:case_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.case_number.invalid_format'),
      )
    end

    it "validates invalid case_number format" do
      applicant = CbvApplicant.new(nyc_attributes.merge(case_number: 'invalid'))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:case_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.case_number.invalid_format')
      )
    end

    it "checks that a shorter case number is invalid" do
      applicant = CbvApplicant.new(nyc_attributes.merge(case_number: '123A'))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:case_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.case_number.invalid_format')
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
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.client_id_number.invalid_format')
      )
    end

    it "requires valid snap_application_date" do
      applicant = CbvApplicant.new(nyc_attributes)
      applicant.snap_application_date = 'invalid'
      expect(applicant).not_to be_valid
      expect(applicant.errors[:snap_application_date]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.invalid_date')
      )
    end

    it "requires client_id_number" do
      applicant = CbvApplicant.new(nyc_attributes.merge(client_id_number: nil))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:client_id_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.client_id_number.invalid_format')
      )
    end
  end
end
