require "rails_helper"

RSpec.describe Nsc do
  describe ".disabled?" do
    it "returns false when NSC_DISABLED is unset" do
      stub_environment_variable("NSC_DISABLED", nil) do
        expect(described_class.disabled?).to be false
      end
    end

    it "returns false when NSC_DISABLED is 'false'" do
      stub_environment_variable("NSC_DISABLED", "false") do
        expect(described_class.disabled?).to be false
      end
    end

    it "returns false when NSC_DISABLED is '0'" do
      stub_environment_variable("NSC_DISABLED", "0") do
        expect(described_class.disabled?).to be false
      end
    end

    it "returns true when NSC_DISABLED is 'true'" do
      stub_environment_variable("NSC_DISABLED", "true") do
        expect(described_class.disabled?).to be true
      end
    end

    it "returns true when NSC_DISABLED is '1'" do
      stub_environment_variable("NSC_DISABLED", "1") do
        expect(described_class.disabled?).to be true
      end
    end

    it "returns true when NSC_DISABLED is 't'" do
      stub_environment_variable("NSC_DISABLED", "t") do
        expect(described_class.disabled?).to be true
      end
    end
  end

  describe ".enabled?" do
    it "returns true when NSC_DISABLED is unset" do
      stub_environment_variable("NSC_DISABLED", nil) do
        expect(described_class.enabled?).to be true
      end
    end

    it "returns false when NSC_DISABLED is 'true'" do
      stub_environment_variable("NSC_DISABLED", "true") do
        expect(described_class.enabled?).to be false
      end
    end
  end
end
