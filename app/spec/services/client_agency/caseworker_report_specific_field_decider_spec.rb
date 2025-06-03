require "rails_helper"

RSpec.describe ClientAgency::CaseworkerReportSpecificFieldDecider, type: :service do
  context "with custom agency configuration" do
    let(:cbv_flow) { build :cbv_flow, client_agency_id: "custom" }

    module ClientAgency
      module Custom
        class ReportFields
          def self.caseworker_fields_for(cbv_flow)
            "custom_answer"
      end

          def self.applicant_fields_for(cbv_flow)
            "custom_answer_applicant"
          end
        end
      end
    end

    it "uses the method pointing to the class for caseworker_fields_for" do
      expect(described_class.caseworker_specific_fields(cbv_flow)).to eq("custom_answer")
    end

    it "uses the method pointing to the class for applicant_specific_fields" do
      expect(described_class.applicant_specific_fields(cbv_flow)).to eq("custom_answer_applicant")
    end
  end

  context "with custom agency configuration for a different method" do
    let(:cbv_flow) { build :cbv_flow, client_agency_id: "other_custom" }

    module ClientAgency
      module OtherCustom
        class ReportFields
        end
      end
    end

    it "returns nothing if no custom class configured for caseworker_fields_for" do
      expect(described_class.caseworker_specific_fields(cbv_flow)).to eq([])
    end

    it "returns nothing if no custom class configured for applicant_specific_fields" do
      expect(described_class.applicant_specific_fields(cbv_flow)).to eq([])
    end
  end

  context "with no custom agency configuration" do
    let(:cbv_flow) { build :cbv_flow, client_agency_id: "random_new_client" }

    it "returns nothing if no custom class configured" do
      expect(described_class.caseworker_specific_fields(cbv_flow)).to eq([])
    end

    it "returns nothing if no custom class configured for applicant_specific_fields" do
      expect(described_class.applicant_specific_fields(cbv_flow)).to eq([])
    end
  end
end
