require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Employment do
  describe '.from_pinwheel' do
    let(:pinwheel_response) do
        {
          "account_id" => "12345",
          "employer_name" => "Acme Corp",
          "start_date" => "2020-01-01",
          "termination_date" => "2021-01-01",
          "status" => "active",
          "employer_phone_number" => { "value" => "123-456-7890" },
          "employer_address" => { "raw" => "123 Main St, Anytown, USA" }
        }
      end

    it 'creates an Employment object with correct attributes' do
      employment = described_class.from_pinwheel(pinwheel_response)
      expect(employment.account_id).to eq("12345")
      expect(employment.employer_name).to eq("Acme Corp")
      expect(employment.start_date).to eq("2020-01-01")
      expect(employment.termination_date).to eq("2021-01-01")
      expect(employment.status).to eq("active")
      expect(employment.employer_phone_number).to eq("123-456-7890")
      expect(employment.employer_address).to eq("123 Main St, Anytown, USA")
      expect(employment.meets_requirements?).to eq(true)
    end

    describe '#.meets_requirements?' do
      it('meets requirements with all attributes') do
        employment = described_class.from_pinwheel(pinwheel_response)
        expect(employment.meets_requirements?).to eq(true)
      end

      it('meets requirements with minimum defined attributes') do
        employment = described_class.from_pinwheel({ "employer_name" => "Acme Corp" })
        expect(employment.meets_requirements?).to eq(true)
      end

      it('does not meet requirements with no attributes') do
        employment = described_class.from_pinwheel({})
        expect(employment.meets_requirements?).to eq(false)
      end

      it('does not meet requirements with blank attributes') do
        employment = described_class.from_pinwheel({ "employer_name" => "" })
        expect(employment.meets_requirements?).to eq(false)
      end
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
        {
          "account" => "67890",
          "employer" => "Beta Inc",
          "hire_date" => "2019-01-01",
          "termination_date" => "2020-01-01",
          "employment_status" => "active"
        }
      end
    it 'creates an Employment object with correct attributes' do
      employment = described_class.from_argyle(argyle_response)
      expect(employment.account_id).to eq("67890")
      expect(employment.employer_name).to eq("Beta Inc")
      expect(employment.start_date).to eq("2019-01-01")
      expect(employment.termination_date).to eq("2020-01-01")
      expect(employment.status).to eq("employed")
    end

    describe '#.meets_requirements? for minimum reporting requirements' do
      it('meets requirements with all defined attributes') do
        employment = described_class.from_argyle(argyle_response)
        expect(employment.meets_requirements?).to eq(true)
      end

      it('meets requirements with minimum defined attributes') do
        employment = described_class.from_argyle({ "employer" => "Acme Corp" })
        expect(employment.meets_requirements?).to eq(true)
      end

      it('does not meet requirements when no attributes defined') do
        employment = described_class.from_argyle({})
        expect(employment.meets_requirements?).to eq(false)
      end

      it('does not meet requirements with attributes defined as empty') do
        employment = described_class.from_argyle({ "employer" => "" })
        expect(employment.meets_requirements?).to eq(false)
      end
    end
  end
end
