require "rails_helper"

RSpec.describe Transmitters::PdfFilenameFormatter do
  describe ".format" do
    let(:cbv_applicant) do
      instance_double(
        CbvApplicant,
        applicant_attributes: [ :case_number ],
        case_number: "ABC1234"
      )
    end

    let(:cbv_flow) do
      instance_double(
        CbvFlow,
        confirmation_code: "SANDBOX001",
        consented_to_authorized_use_at: Time.zone.parse("2025-01-01 08:00:30"),
        cbv_applicant: cbv_applicant
      )
    end

    it "injects the confirmation code" do
      expect(described_class.format(cbv_flow, "Conf%{confirmation_code}"))
        .to eq("ConfSANDBOX001")
    end

    it "injects the consent date" do
      expect(described_class.format(cbv_flow, "CBVPilot_%{consent_date}"))
        .to eq("CBVPilot_20250101")
    end

    it "injects applicant attributes referenced by name" do
      expect(described_class.format(cbv_flow, "Case_%{case_number}"))
        .to eq("Case_ABC1234")
    end

    it "formats the target sftp filename pattern" do
      expect(described_class.format(cbv_flow, "CBV_%{case_number}_%{consent_timestamp}_%{confirmation_code}.pdf"))
        .to eq("CBV_ABC1234_20250101080030_SANDBOX001.pdf")
    end
  end
end
