require "rails_helper"

RSpec.describe ClientAgency do
  context "invalid config" do
    describe "#initialize" do
      context "missing id" do
        let(:sample_config) { <<~YAML }
          - id:
            agency_name: Foo Agency Name
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: shared_email
            transmission_method_configuration:
              email: foo
        YAML

        it "raises an error" do
          config = YAML.safe_load(sample_config).first
          expect do
            ClientAgencyConfig::ClientAgency.new(config)
          end.to raise_error(ArgumentError, "Client Agency missing id")
        end
      end

      context "missing agency_name" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name:
            pinwheel:
              environment: foo
            argyle:
              environment: foo
        YAML

        it "raises an error" do
          config = YAML.safe_load(sample_config).first
          expect do
            ClientAgencyConfig::ClientAgency.new(config)
          end.to raise_error(ArgumentError, "Client Agency foo missing required attribute `agency_name`")
        end
      end

      context "incorrect pay income w2 configuration" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            pay_income_days:
              w2: 0
              gig: 182
        YAML

        it "raises an error" do
          config = YAML.safe_load(sample_config).first
          expect do
            ClientAgencyConfig::ClientAgency.new(config)
          end.to raise_error(ArgumentError, "Client Agency foo invalid value for pay_income_days.w2")
        end
      end

      context "incorrect pay income gig configuration" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            pay_income_days:
              w2: 90
              gig: 0
            transmission_method: shared_email
        YAML

        it "raises an error" do
          config = YAML.safe_load(sample_config).first
          expect do
            ClientAgencyConfig::ClientAgency.new(config)
          end.to raise_error(ArgumentError, "Client Agency foo invalid value for pay_income_days.gig")
        end
      end

      context "missing transmission method" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method:
        YAML

        it "raises an error" do
          config = YAML.safe_load(sample_config).first
          expect do
            ClientAgencyConfig::ClientAgency.new(config)
          end.to raise_error(ArgumentError, "Client Agency foo missing required attribute `transmission_method`")
        end
      end
    end
  end
end
