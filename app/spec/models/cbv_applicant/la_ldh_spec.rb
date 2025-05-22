require 'rails_helper'
require_relative "../cbv_applicant_spec.rb"

RSpec.describe CbvApplicant::LaLdh, type: :model do
  let(:la_ldh_attributes) { attributes_for(:cbv_applicant, :la_ldh) }

  context "user input is valid" do
    it "case_number is optional" do
      applicant = CbvApplicant.new(la_ldh_attributes.without(:case_number))
      expect(applicant).to be_valid
      expect(applicant.class.name).to eq("CbvApplicant::LaLdh")
    end
  end

  it "redacts all sensitive PII fields" do
    applicant = CbvApplicant.create(la_ldh_attributes)
    applicant.redact!
    expect(applicant).to have_attributes(
      first_name: "REDACTED",
      middle_name: "REDACTED",
      last_name: "REDACTED",
      date_of_birth: Date.new(1990, 1, 1),
      case_number: /[0-9]+/, # Not redacted as it's not sensitive PII
    )
  end
end
