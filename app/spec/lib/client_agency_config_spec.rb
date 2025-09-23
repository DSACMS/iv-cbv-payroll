require "rails_helper"

RSpec.describe ClientAgencyConfig do
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
          ClientAgencyConfig.new(sample_config_path)
        end.not_to raise_error
      end
    end

    describe "#client_agency_ids" do
      it "returns the IDs" do
        config = ClientAgencyConfig.new(sample_config_path)
        expect(config.client_agency_ids).to match_array([ "foo", "bar" ])
      end
    end

    describe "for a particular client agency" do
      it "returns a key for that agency" do
        config = ClientAgencyConfig.new(sample_config_path)
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
            ClientAgencyConfig.new(sample_config_path)
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
            ClientAgencyConfig.new(sample_config_path)
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
            ClientAgencyConfig.new(sample_config_path)
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
            ClientAgencyConfig.new(sample_config_path)
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
            ClientAgencyConfig.new(sample_config_path)
          end.to raise_error(ArgumentError, "Client Agency foo missing required attribute `transmission_method`")
        end
      end
    end
  end
end
