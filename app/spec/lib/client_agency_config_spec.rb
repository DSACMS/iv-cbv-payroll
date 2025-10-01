require "rails_helper"

RSpec.describe ClientAgencyConfig do
  let(:config_dir) { "/fake/client-agency-config" }
  let(:foo_path)   { File.join(config_dir, "foo.yml") }
  let(:sample_config) { <<~YAML }
    id: foo
    agency_name: Foo Agency Name
    pinwheel:
      environment: foo
    argyle:
      environment: foo
    transmission_method: shared_email
    transmission_method_configuration:
      email: foo
  YAML

  before do
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob)
                    .with(File.join(config_dir, "*.yml"))
                    .and_return([ foo_path ])

    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read)
                     .with(foo_path)
                     .and_return(sample_config)
  end

  describe "#initialize" do
    it "loads the client agency config" do
      expect do
        ClientAgencyConfig.new(config_dir, true)
      end.not_to raise_error
    end
  end

  describe "#client_agency_ids" do
    it "returns the IDs" do
      config = ClientAgencyConfig.new(config_dir, true)
      expect(config.client_agency_ids).to match_array([ "foo" ])
    end
  end

  describe "for a particular client agency" do
    it "returns the config for that agency" do
      config = ClientAgencyConfig.new(config_dir, true)
      expect(config["foo"].agency_name).to eq("Foo Agency Name")
    end
  end
end
