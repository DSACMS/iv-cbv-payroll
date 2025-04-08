require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Identity do
  describe '.from_pinwheel' do
    let(:pinwheel_response) do
        {
          "account_id" => "12345",
          "full_name" => "John Doe"
        }
      end


    it 'creates an Identity object from pinwheel response' do
      identity = described_class.from_pinwheel(pinwheel_response)
      expect(identity.account_id).to eq("12345")
      expect(identity.full_name).to eq("John Doe")
    end

    describe '#.meets_requirements?' do
      it('meets requirements with all attributes') do
        identity = described_class.from_pinwheel(pinwheel_response)
        expect(identity.meets_requirements?).to eq(true)
      end

      it('meets requirements with minimum defined attributes') do
        identity = described_class.from_pinwheel({ "full_name" => "Joe Smith" })
        expect(identity.meets_requirements?).to eq(true)
      end

      it('does not meet requirements with no attributes') do
        identity = described_class.from_pinwheel({})
        expect(identity.meets_requirements?).to eq(false)
      end

      it('does not meet requirements with blank attributes') do
        identity = described_class.from_pinwheel({ "full_name" => "" })
        expect(identity.meets_requirements?).to eq(false)
      end
    end
  end

  describe '.from_argyle' do
    let(:argyle_response) do
       {
         "account" => "67890",
         "full_name" => "Jane Smith"
       }
     end

    it 'creates an Identity object from argyle response' do
      identity = described_class.from_argyle(argyle_response)
      expect(identity.account_id).to eq("67890")
      expect(identity.full_name).to eq("Jane Smith")
    end

    describe '#.meets_requirements?' do
      it('meets requirements with all attributes') do
        identity = described_class.from_argyle(argyle_response)
        expect(identity.meets_requirements?).to eq(true)
      end

      it('meets requirements with minimum defined attributes') do
        identity = described_class.from_argyle({ "full_name" => "Joe Smith" })
        expect(identity.meets_requirements?).to eq(true)
      end

      it('does not meet requirements with no attributes') do
        identity = described_class.from_argyle({})
        expect(identity.meets_requirements?).to eq(false)
      end

      it('does not meet requirements with blank attributes') do
        identity = described_class.from_argyle({ "full_name" => "" })
        expect(identity.meets_requirements?).to eq(false)
      end
    end
  end
end
