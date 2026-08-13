require "rails_helper"

RSpec.describe ProcessedDownloadService do
  let(:service) { instance_double(ActiveStorage::Service) }
  let(:destination) { Rails.root.join("tmp", "processed-download-service-spec") }

  after { FileUtils.rm_f(destination) }

  it "downloads the object from the configured Active Storage service" do
    allow(service).to receive(:download).with("processed-key").and_return("cleared document")

    described_class.new(service: service).download_file("processed-key", destination)

    expect(File.binread(destination)).to eq("cleared document")
  end

  it "propagates a download failure without creating a destination file" do
    allow(service).to receive(:download).with("missing-key").and_raise(ActiveStorage::FileNotFoundError)

    expect {
      described_class.new(service: service).download_file("missing-key", destination)
    }.to raise_error(ActiveStorage::FileNotFoundError)
    expect(destination).not_to exist
  end
end
