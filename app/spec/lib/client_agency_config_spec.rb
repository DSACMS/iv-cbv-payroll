require "rails_helper"

RSpec.describe ClientAgencyConfig do
  context 'with mocked config' do
    let(:sample_config_path) { "/fake/path.yml" }
    let(:sample_config) { raise "define in spec" }

    before do
      allow(File).to receive(:read)
        .with(sample_config_path)
        .and_return(sample_config)
    end

    context 'valid config' do
      let(:sample_config) { <<~YAML }
        - id: foo
          agency_name: Foo Agency Name
          pinwheel:
            environment: foo
          argyle:
            environment: foo
          transmission_method: foo
        - id: bar
          agency_name: Bar Agency Name
          pinwheel:
            environment: bar
          argyle:
            environment: foo
          transmission_method: foo
      YAML

      describe "#initialize" do
        it "loads the client agency config" do
          expect do
            described_class.new(sample_config_path)
          end.not_to raise_error
        end
      end

      describe "#client_agency_ids" do
        it "returns the IDs" do
          config = described_class.new(sample_config_path)
          expect(config.client_agency_ids).to contain_exactly("foo", "bar")
        end
      end

      describe "for a particular client agency" do
        it "returns a key for that agency" do
          config = described_class.new(sample_config_path)
          expect(config["foo"].agency_name).to eq("Foo Agency Name")
        end
      end
    end

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
          YAML

          it "raises an error" do
            expect do
              described_class.new(sample_config_path)
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
            expect do
              described_class.new(sample_config_path)
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
            expect do
              described_class.new(sample_config_path)
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
            expect do
              described_class.new(sample_config_path)
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
            expect do
              described_class.new(sample_config_path)
            end.to raise_error(ArgumentError, "Client Agency foo missing required attribute `transmission_method`")
          end
        end
      end
    end
  end

  describe "actual config file" do
    let(:actual_config) { Rails.application.config.client_agencies }

    it "has at least one agency defined" do
      expect(actual_config.client_agency_ids).not_to be_empty
    end

    it "has sandbox agency defined" do
      expect(actual_config.client_agency_ids).to include("sandbox")
    end

    it "has all agencies properly configured with required attributes" do
      actual_config.client_agency_ids.each do |agency_id|
        agency = actual_config[agency_id]

        expect(agency.id).to eq(agency_id), "Agency #{agency_id} has mismatched id"
        expect(agency.agency_name).to be_present, "Agency #{agency_id} missing agency_name"
        expect(agency.transmission_method).to be_present, "Agency #{agency_id} missing transmission_method"
        expect(agency.pay_income_days).to be_present, "Agency #{agency_id} missing pay_income_days"
        expect(agency.pay_income_days[:w2]).to be_in(ClientAgencyConfig::VALID_PAY_INCOME_DAYS),
          "Agency #{agency_id} has invalid w2 pay_income_days"
        expect(agency.pay_income_days[:gig]).to be_in(ClientAgencyConfig::VALID_PAY_INCOME_DAYS),
          "Agency #{agency_id} has invalid gig pay_income_days"
      end
    end

    it "has sandbox agency with expected configuration for development/test defaults" do
      sandbox = actual_config["sandbox"]

      expect(sandbox).to be_present
      expect(sandbox.id).to eq("sandbox")
      expect(sandbox.agency_name).to be_present
      expect(sandbox.transmission_method).to be_present
    end

    context "sandbox agency requirement" do
      it "ensures sandbox exists for ApplicationController default agency fallback in dev/test" do
        # This test protects the assumption made in ApplicationController#current_agency
        # where we default to sandbox in development/test environments when no agency
        # can be determined. If this test fails, the default fallback logic needs updating.

        expect(actual_config["sandbox"]).to be_present,
          "Sandbox agency is required for ApplicationController default agency fallback in development/test environments"
      end
    end
  end
end
