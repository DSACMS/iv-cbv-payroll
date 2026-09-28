require "rails_helper"
require "rake"
require "open-uri"
require "tmpdir"

RSpec.describe Rake::Task, "#invoke" do # rubocop:disable RSpec/SpecFilePathFormat -- Specs are named after the rake file.
  let(:license_url) { "https://raw.githubusercontent.com/scalar/scalar/20151e227922fb9423f71ff8e6f8b6b04c668917/LICENSE" }
  let(:license) { "Scalar license test fixture\n" }
  let(:task) { described_class["api_docs:scalar_license"] }
  let(:directory) { Dir.mktmpdir("api-docs-license-") }
  let(:output) { Pathname.new(directory).join("site") }

  around do |example|
    original_rake_application = Rake.application
    Rake.application = Rake::Application.new
    load Rails.root.join("lib/tasks/api_docs.rake")

    example.run
  ensure
    Rake.application = original_rake_application
  end

  before do
    allow(Rails.root).to receive(:join).and_call_original
    allow(Rails.root).to receive(:join).with("tmp/api-docs").and_return(output)
  end

  after { FileUtils.remove_entry(directory) }

  it "includes the license download in the site build" do
    expect(described_class["api_docs:build"].prerequisite_tasks).to include(task)
  end

  it "writes the downloaded notice only into the generated site" do
    stub_request(:get, license_url).to_return(status: 200, body: license)

    task.invoke

    expect(output.join("scalar-LICENSE").read).to eq(license)
  end

  it "fails rather than publishing an HTTP error as the license" do
    stub_request(:get, license_url).to_return(status: 404, body: "Not found")

    expect { task.invoke }.to raise_error(OpenURI::HTTPError)
    expect(output.join("scalar-LICENSE")).not_to exist
  end

  it "fails when the download times out" do
    stub_request(:get, license_url).to_timeout

    expect { task.invoke }.to raise_error(Timeout::Error)
    expect(output.join("scalar-LICENSE")).not_to exist
  end
end
