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

  describe '#redact!' do
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

  describe '#redact_member_names_in_json' do
    let(:applicant) { CbvApplicant::AzDes.new(az_attributes) }

    subject { applicant.send(:redact_member_names_in_json, input) }

    context 'when input is not an array' do
      let(:input) { "not an array" }

      it 'returns input unchanged' do
        expect(subject).to eq("not an array")
      end
    end

    context 'when using real income_changes data from factory' do
      let(:input) { attributes_for(:cbv_applicant, :az_des)[:income_changes] }

      it 'redacts member_name fields and preserves other fields' do
        result = subject

        expect(result.length).to eq(2)
        result.each do |income_change|
          expect(income_change["member_name"]).to eq("REDACTED")
          expect(income_change["employer_name"]).to be_present
        end
      end
    end

    context 'when member_name is nil or missing' do
      let(:input) do
        [
          { "member_name" => nil, "employer_name" => "Test Co" },
          { "employer_name" => "Missing Co" }
        ]
      end

      it 'redacts existing member_name fields (including nil), skips missing ones' do
        expect(subject).to eq([
          { "member_name" => "REDACTED", "employer_name" => "Test Co" },
          { "employer_name" => "Missing Co" }
        ])
      end
    end
  end
end
