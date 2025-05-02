require 'rails_helper'

RSpec.describe CbvApplicant, type: :model do
  describe "all valid types of agencies" do
    ClientAgencyConfig.client_agencies.client_agency_ids.each do |client_agency_id|
      it "has a list of VALID_ATTRIBUTES for #{client_agency_id}" do
        expect(CbvApplicant.valid_attributes_for_agency(client_agency_id)).to be_present
      end
    end
  end

  describe "#has_applicant_attribute_missing?" do
    before do
      allow_any_instance_of(ClientAgencyConfig::ClientAgency).to receive(:applicant_attributes).and_return(
        { first_name: "required" }
      )
    end

    let(:cbv_applicant) { create(:cbv_applicant, first_name: nil) }
    it "returns true if a field missing" do
      cbv_applicant.set_applicant_attributes
      expect(cbv_applicant.required_applicant_attributes).to be_present
      expect(cbv_applicant.has_applicant_attribute_missing?).to eq(true)
    end

    it "returns false if a field not missing" do
      cbv_applicant.set_applicant_attributes
      cbv_applicant.first_name = "Dean Venture"
      expect(cbv_applicant.has_applicant_attribute_missing?).to eq(false)
    end
  end

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

    describe "date_of_birth" do
      let(:date_of_birth) { Date.new(1980, 1, 1) }

      context "for sandbox agency" do
        before do
          allow_any_instance_of(ClientAgencyConfig::ClientAgency).to receive(:applicant_attributes).and_return(
            {
              first_name: { "required" => true },
              date_of_birth: { "required" => true }
            }
          )
        end

        it "is required" do
          applicant = build(:cbv_applicant, :sandbox, date_of_birth: nil)
          applicant.set_applicant_attributes
          applicant.validate_required_applicant_attributes
          expect(applicant.errors[:date_of_birth]).to include(
            I18n.t("cbv.applicant_informations.sandbox.fields.date_of_birth.blank")
          )
        end

        it "is valid when provided" do
          applicant = build(:cbv_applicant, :sandbox, date_of_birth: date_of_birth)
          applicant.set_applicant_attributes
          applicant.validate_required_applicant_attributes
          expect(applicant.errors[:date_of_birth]).to be_empty
        end
      end

      context "for la_ldh agency" do
        before do
          allow_any_instance_of(ClientAgencyConfig::ClientAgency).to receive(:applicant_attributes).and_return(
            {
              case_number: { "required" => false },
              date_of_birth: { "required" => true }
            }
          )
        end

        it "is required" do
          applicant = build(:cbv_applicant, :la_ldh, date_of_birth: nil)
          applicant.set_applicant_attributes
          applicant.validate_required_applicant_attributes
          expect(applicant.errors[:date_of_birth]).to include(
            I18n.t("cbv.applicant_informations.la_ldh.fields.date_of_birth.blank")
          )
        end

        it "is valid when provided" do
          applicant = build(:cbv_applicant, :la_ldh, date_of_birth: date_of_birth)
          applicant.set_applicant_attributes
          applicant.validate_required_applicant_attributes
          expect(applicant.errors[:date_of_birth]).to be_empty
        end
      end

      context "for other agencies" do
        it "is not required for nyc agency" do
          applicant = build(:cbv_applicant, :nyc, date_of_birth: nil)
          applicant.set_applicant_attributes
          applicant.validate_required_applicant_attributes
          expect(applicant.errors[:date_of_birth]).to be_empty
        end
      end
    end
  end
end
