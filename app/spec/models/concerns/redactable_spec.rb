require 'rails_helper'

RSpec.describe Redactable do
  let(:test_instance) do
    Class.new(ApplicationRecord) do
      include Redactable
      self.table_name = 'cbv_applicants' # Use existing table for testing
    end.new
  end

  describe '#redact_member_names_in_json' do
    subject { test_instance.send(:redact_member_names_in_json, input) }

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
