require 'rails_helper'

RSpec.describe CbvApplicant, type: :model do
  describe "validations" do
    let(:valid_attributes) { attributes_for(:cbv_applicant, :nyc) }

    it "allows middle_name to be optional" do
      applicant = create(:cbv_applicant, middle_name: nil)
      expect(applicant).to be_valid
    end

    describe "snap_application_date" do
      it "does not require snap_application_date in the generic link workflow, sets default" do
        applicant = CbvApplicant.new(valid_attributes)
        expect(applicant).to be_valid
        expect(applicant.snap_application_date).to eq(Date.current)
      end

      it "requires a snap_application_date in the caseworker workflow" do
        applicant = CbvApplicant.new(valid_attributes)
        applicant.snap_application_date = nil
        expect(applicant).not_to be_valid
      end

      it "validates snap_application_date is not in the future" do
        applicant = CbvApplicant.new(valid_attributes)
        applicant.snap_application_date = Date.tomorrow
        expect(applicant).not_to be_valid
        expect(applicant.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.invalid_date')
        )
      end

      it "parses snap_application_date strings correctly" do
        applicant = CbvApplicant.new(valid_attributes)
        applicant.snap_application_date = "08/15/2023"
        expect(applicant).not_to be_valid
        expect(applicant.snap_application_date).to eq(Date.new(2023, 8, 15))
      end

      it "adds an error when snap_application_date is not a valid date in a caseworker workflow" do
        applicant = CbvApplicant.new(valid_attributes)
        applicant.snap_application_date = "invalid"
        expect(applicant).not_to be_valid
        expect(applicant.errors[:snap_application_date]).to include(
          I18n.t('activerecord.errors.models.cbv_applicant/nyc.attributes.snap_application_date.invalid_date')
        )
      end
    end
  end
end
