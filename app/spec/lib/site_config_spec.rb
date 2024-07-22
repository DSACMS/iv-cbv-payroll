require "rails_helper"

RSpec.describe SiteConfig do
  let(:sample_config_path) { "/fake/path.yml" }
  let(:sample_config) { <<~YAML }
    - id: foo
    - id: bar
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
      expect(config.site_ids).to match_array(["foo", "bar"])
    end
  end
end
