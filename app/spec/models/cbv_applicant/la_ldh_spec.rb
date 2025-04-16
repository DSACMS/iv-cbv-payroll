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
end
