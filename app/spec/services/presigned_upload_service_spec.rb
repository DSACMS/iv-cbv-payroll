require "rails_helper"
require "active_storage/service/s3_service"

RSpec.describe PresignedUploadService do
  let(:checksum) { Digest::MD5.base64digest("%PDF-1.4") }
  let(:pdf) { { filename: "verification.pdf", content_type: "application/pdf", byte_size: 1_024, checksum: checksum } }

  def policy_conditions(upload)
    JSON.parse(Base64.decode64(upload[:fields]["policy"])).fetch("conditions")
  end

  describe "#call" do
    it "returns one upload descriptor per requested file" do
      uploads = described_class.new.call([
        pdf,
        { filename: "photo.jpg", content_type: "image/jpeg", byte_size: 2_048, checksum: checksum }
      ])

      expect(uploads.map { |upload| upload[:filename] }).to eq(%w[verification.pdf photo.jpg])
      expect(uploads.map { |upload| upload[:signed_id] }.uniq.length).to eq(2)
    end

    it "creates the blob up front so the form only has to submit a signed ID" do
      expect { described_class.new.call([ pdf ]) }.to change(ActiveStorage::Blob, :count).by(1)

      blob = ActiveStorage::Blob.last

      expect(blob.filename.to_s).to eq("verification.pdf")
      expect(blob.content_type).to eq("application/pdf")
      expect(blob.byte_size).to eq(1_024)
      expect(blob.checksum).to eq(checksum)
      expect(blob.service_name).to eq(described_class::SERVICE_NAME.to_s)
    end

    it "marks the blob identified and analyzed so nothing tries to download it" do
      described_class.new.call([ pdf ])

      expect(ActiveStorage::Blob.last).to be_identified
      expect(ActiveStorage::Blob.last).to be_analyzed
    end

    it "returns a signed ID that resolves back to the blob" do
      upload = described_class.new.call([ pdf ]).first

      expect(ActiveStorage::Blob.find_signed!(upload[:signed_id])).to eq(ActiveStorage::Blob.last)
    end

    it "does not let the client choose the object key" do
      upload = described_class.new.call([ pdf ]).first
      key = ActiveStorage::Blob.find_signed!(upload[:signed_id]).key

      expect(key).to match(/\A[a-z0-9]{28}\z/)
      expect(upload[:fields]["key"]).to eq(key)
    end

    it "rejects a content type outside the allowlist before signing anything" do
      expect {
        described_class.new.call([ pdf.merge(content_type: "application/x-msdownload") ])
      }.to raise_error(described_class::UnacceptableUpload) { |error|
        expect(error.reason).to eq(:unsupported_type)
      }
    end

    it "rejects a file larger than the upload limit" do
      expect {
        described_class.new.call([ pdf.merge(byte_size: described_class::MAX_UPLOAD_BYTES + 1) ])
      }.to raise_error(described_class::UnacceptableUpload) { |error|
        expect(error.reason).to eq(:too_large)
      }
    end

    it "rejects an empty file" do
      expect {
        described_class.new.call([ pdf.merge(byte_size: 0) ])
      }.to raise_error(described_class::UnacceptableUpload) { |error|
        expect(error.reason).to eq(:empty)
      }
    end

    it "rejects a malformed checksum" do
      expect {
        described_class.new.call([ pdf.merge(checksum: "not-a-digest") ])
      }.to raise_error(described_class::UnacceptableUpload) { |error|
        expect(error.reason).to eq(:upload_failed)
      }
    end

    it "leaves no blob behind when one file in the batch is unacceptable" do
      expect {
        expect {
          described_class.new.call([ pdf, pdf.merge(byte_size: 0) ])
        }.to raise_error(described_class::UnacceptableUpload)
      }.not_to change(ActiveStorage::Blob, :count)
    end

    it "points uploads at the local stand-in when the unscanned service is Disk" do
      upload = described_class.new.call([ pdf ]).first

      expect(upload[:url]).to eq(Rails.application.routes.url_helpers.fake_s3_uploads_path)
    end
  end

  describe "#call against S3" do
    subject(:upload) { described_class.new(service: service).call([ pdf ]).first }

    let(:service) do
      ActiveStorage::Service::S3Service.new(
        bucket: "emmy-test-unscanned-uploads",
        region: "us-east-1",
        access_key_id: "AKIATEST",
        secret_access_key: "secret"
      )
    end


    it "posts to the bucket itself rather than to the app" do
      expect(upload[:url]).to include("emmy-test-unscanned-uploads")
      expect(upload[:fields]).to include("policy", "x-amz-signature", "x-amz-credential")
    end

    it "bounds the upload size in the policy so S3 itself rejects an oversized body" do
      expect(policy_conditions(upload)).to include(
        [ "content-length-range", 0, described_class::MAX_UPLOAD_BYTES ]
      )
    end

    it "pins the exact key and content type in the signed policy" do
      key = ActiveStorage::Blob.find_signed!(upload[:signed_id]).key

      expect(policy_conditions(upload)).to include(
        { "key" => key },
        { "Content-Type" => "application/pdf" },
        { "bucket" => "emmy-test-unscanned-uploads" }
      )
    end
  end
end
