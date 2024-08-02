require "rails_helper"

RSpec.describe SiteConfig do
  let(:sample_config_path) { "/fake/path.yml" }
  let(:sample_config) { <<~YAML }
    - id: foo
      agency_name: Foo Agency Name
      pinwheel:
        api_token: foo
        environment: foo
    - id: bar
      agency_name: Bar Agency Name
      pinwheel:
        api_token: bar
        environment: bar
  YAML

  before do
    allow(File).to receive(:read)
      .with(sample_config_path)
      .and_return(sample_config)
  end

  describe "#initialize" do
    it "loads the site config" do
      expect do
        SiteConfig.new(sample_config_path)
      end.not_to raise_error
    end
  end

  describe "#site_ids" do
    it "returns the IDs" do
      config = SiteConfig.new(sample_config_path)
      expect(config.site_ids).to match_array([ "foo", "bar" ])
    end
  end

  describe "for a particular site" do
    it "returns a key for that agency" do
      config = SiteConfig.new(sample_config_path)
      expect(config["foo"].agency_name).to eq("Foo Agency Name")
    end
  end
end
