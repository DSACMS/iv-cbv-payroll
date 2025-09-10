require 'rails_helper'
require_relative "../cbv_applicant_spec.rb"

RSpec.describe CbvApplicant::PaDhs, type: :model do
  let(:pa_attributes) { attributes_for(:cbv_applicant, :pa_dhs) }

  # PA does not necessarily require case number; leaving this here as an example but may not be needed
  # as we are waiting for PA requirements.

  # context "user input is invalid" do
  #   it "requires case_number" do
  #     applicant = CbvApplicant.new(pa_attributes.without(:case_number))
  #     expect(applicant).not_to be_valid
  #     expect(applicant.errors[:case_number]).to include(
  #       I18n.t('activerecord.errors.models.cbv_applicant/pa_dhs.attributes.case_number.blank'),
  #     )
  #   end
  # end

  describe '#redact!' do
    context 'when input is valid' do
      it "redacts all sensitive PII fields" do
        applicant = CbvApplicant.create(pa_attributes)
        applicant.redact!

        expect(applicant).to have_attributes(
          first_name: "REDACTED",
          middle_name: "REDACTED",
          last_name: "REDACTED",
          case_number: /[0-9]+/ # Not redacted as it's not sensitive PII
        )

        expect(applicant.income_changes).to be_present
        applicant.income_changes.each do |income_change|
          expect(income_change["member_name"]).to eq("REDACTED")
          # these should not have changed
          expect(income_change["employer_name"]).not_to eq("REDACTED")
          expect(income_change["change_type"]).not_to eq("REDACTED")
        end
      end
    end

    context 'when income_changes is not an array' do
      let(:input) { "not an array" }

      it 'returns input unchanged' do
        applicant = CbvApplicant.create(pa_attributes)
        applicant.income_changes = input
        applicant.redact!

        expect(applicant.income_changes).to eq(input)
      end
    end

    context 'when member_name is nil or missing' do
      let(:income_changes) do
        [ { "member_name" => nil, "employer_name" => "Test Co" }, { "employer_name" => "Missing Co" } ]
      end

      it 'redacts existing member_name fields (including nil), skips missing ones' do
        applicant = CbvApplicant.create(pa_attributes.merge(income_changes: income_changes))
        applicant.redact!

        expect(applicant.income_changes).to eq([
          { "member_name" => "REDACTED", "employer_name" => "Test Co" },
          { "employer_name" => "Missing Co" }
        ])
      end
    end
  end

  describe "#agency_expected_names" do
    let(:applicant) { create(:cbv_applicant, :pa_dhs) }

    it "returns an array of names" do
      expect(applicant.agency_expected_names).to eq([
        "Mark Scout_PA"
      ])
    end
  end
end
