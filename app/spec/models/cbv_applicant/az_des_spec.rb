require 'rails_helper'
require_relative "../cbv_applicant_spec.rb"

RSpec.describe CbvApplicant::AzDes, type: :model do
  let(:az_attributes) { attributes_for(:cbv_applicant, :az_des) }

  context "user input is invalid" do
    it "requires case_number" do
      applicant = CbvApplicant.new(az_attributes.without(:case_number))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:case_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/az_des.attributes.case_number.blank'),
      )
    end
  end

  it "redacts all sensitive PII fields" do
    applicant = CbvApplicant.create(az_attributes)
    applicant.redact!
    expect(applicant).to have_attributes(
      first_name: "REDACTED",
      middle_name: "REDACTED",
      last_name: "REDACTED",
      case_number: /[0-9]+/, # Not redacted as it's not sensitive PII
    )

    expect(applicant.income_changes).to be_present
    applicant.income_changes.each do |income_change|
      expect(income_change["member_name"]).to eq("REDACTED")
      # sanity check - verify other fields are not redacted
      expect(income_change["employer_name"]).not_to eq("REDACTED")
      expect(income_change["change_type"]).not_to eq("REDACTED")
    end
  end
end
