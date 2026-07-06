require "rails_helper"

RSpec.describe ClientAgencyConfig do
  let(:sample_config_path) { "/fake/path.yml" }
  let(:sample_config) { nil }

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read)
      .with(sample_config_path)
      .and_return(sample_config)
  end

  context 'valid config' do
    let(:sample_config) { <<~YAML }
      - id: foo
        agency_name: Foo Agency Name
        renewal_required_months: 2
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

      it "returns renewal_required_months when configured" do
        config = described_class.new(sample_config_path)
        expect(config["foo"].renewal_required_months).to eq(2)
      end

      it "defaults allowed_iframe_ancestors to an empty array" do
        config = described_class.new(sample_config_path)
        expect(config["foo"].allowed_iframe_ancestors).to eq([])
      end
    end
  end

  context "allowed_iframe_ancestors configuration" do
    describe "#allowed_iframe_ancestors" do
      context "when given a YAML list" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: Foo Agency Name
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: foo
            allowed_iframe_ancestors:
              - https://example-portal.com
              - https://partner.gov
        YAML

        it "returns the list of origins" do
          config = described_class.new(sample_config_path)
          expect(config["foo"].allowed_iframe_ancestors)
            .to eq([ "https://example-portal.com", "https://partner.gov" ])
        end
      end

      context "when not a list (e.g. a string)" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: Foo Agency Name
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: foo
            allowed_iframe_ancestors: "https://example-portal.com"
        YAML

        it "raises an error" do
          expect do
            described_class.new(sample_config_path)
          end.to raise_error(ArgumentError, "Client Agency foo `allowed_iframe_ancestors` must be a list")
        end
      end

      context "when omitted" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: Foo Agency Name
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: foo
        YAML

        it "returns an empty array" do
          config = described_class.new(sample_config_path)
          expect(config["foo"].allowed_iframe_ancestors).to eq([])
        end
      end
    end
  end

  context "real client agency config" do
    around do |example|
      original_value = ENV["LA_LDH_CASEWORKER_FALLBACK_EMAIL"]
      ENV["LA_LDH_CASEWORKER_FALLBACK_EMAIL"] = "fallback@example.gov"
      example.run
    ensure
      ENV["LA_LDH_CASEWORKER_FALLBACK_EMAIL"] = original_value
    end

    it "loads the LA LDH caseworker fallback email from the environment" do
      config = described_class.new(Rails.root.join("config/client-agency-config.yml"))

      expect(config["la_ldh"].caseworker_fallback_email).to eq("fallback@example.gov")
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

      context "invalid renewal required months" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            renewal_required_months: 0
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: shared_email
        YAML

        it "raises an error" do
          expect do
            described_class.new(sample_config_path)
          end.to raise_error(ArgumentError, "Client Agency foo invalid value for renewal_required_months")
        end
      end

      context "renewal required months above the max" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            renewal_required_months: 7
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: shared_email
        YAML

        it "raises an error" do
          expect do
            described_class.new(sample_config_path)
          end.to raise_error(ArgumentError, "Client Agency foo invalid value for renewal_required_months")
        end
      end

      context "applicant attribute with an invalid redaction_type" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: shared_email
            applicant_attributes:
              case_number:
                redaction_type: bogus
        YAML

        it "raises an error" do
          expect do
            described_class.new(sample_config_path)
          end.to raise_error(ArgumentError, /applicant attribute `case_number` has an invalid `redaction_type`: "bogus"/)
        end
      end

      context "applicant attribute with no redaction_type" do
        let(:sample_config) { <<~YAML }
          - id: foo
            agency_name: foo
            pinwheel:
              environment: foo
            argyle:
              environment: foo
            transmission_method: shared_email
            applicant_attributes:
              case_number:
                required: true
        YAML

        it "does not raise an error" do
          expect do
            described_class.new(sample_config_path)
          end.not_to raise_error
        end
      end
    end
  end

  describe "VALID_REDACTION_TYPES" do
    it "only contains types Redactable can actually replace" do
      expect(Redactable::REDACTION_REPLACEMENTS.keys)
        .to include(*described_class::VALID_REDACTION_TYPES.map(&:to_sym))
    end
  end

  describe "#redactable_applicant_fields" do
    let(:sample_config) { <<~YAML }
      - id: foo
        agency_name: foo
        pinwheel:
          environment: foo
        argyle:
          environment: foo
        transmission_method: shared_email
        applicant_attributes:
          first_name:
            required: true
            redaction_type: string
          case_number:
            required: true
          date_of_birth:
            required: true
            redaction_type: date
    YAML

    it "maps only attributes with a redaction_type to their type symbol" do
      config = described_class.new(sample_config_path)
      expect(config["foo"].redactable_applicant_fields)
        .to eq({ first_name: :string, date_of_birth: :date })
    end
  end
end
