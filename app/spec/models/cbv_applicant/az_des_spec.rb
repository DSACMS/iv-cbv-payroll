require 'rails_helper'
require_relative "../cbv_applicant_spec.rb"

RSpec.describe CbvApplicant::AzDes, type: :model do
  let(:az_attributes) { attributes_for(:cbv_applicant, :az_des) }

  it_behaves_like "a CbvApplicant subclass", "az_des"

  context "user input is invalid" do
    it "requires case_number" do
      applicant = CbvApplicant.new(az_attributes.without(:case_number))
      expect(applicant).not_to be_valid
      expect(applicant.errors[:case_number]).to include(
        I18n.t('activerecord.errors.models.cbv_applicant/az_des.attributes.case_number.blank'),
      )
    end
  end
end
