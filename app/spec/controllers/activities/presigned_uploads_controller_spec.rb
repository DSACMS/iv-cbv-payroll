require "rails_helper"

RSpec.describe Activities::PresignedUploadsController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) { create(:activity_flow) }
  let(:json) { response.parsed_body }
  let(:checksum) { Digest::SHA256.base64digest("%PDF-1.4") }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "POST #create" do
    it "returns one presigned upload per requested file" do
      post :create, params: {
        files: [
          { filename: "verification.pdf", content_type: "application/pdf", byte_size: 1_024, checksum: checksum },
          { filename: "photo.jpg", content_type: "image/jpeg", byte_size: 2_048, checksum: checksum }
        ]
      }, format: :json

      expect(response).to have_http_status(:ok)
      expect(json["uploads"].map { |upload| upload["filename"] }).to eq(%w[verification.pdf photo.jpg])
      expect(json["uploads"]).to all(include("url", "fields", "signed_id"))
    end

    it "returns a signed ID that resolves to the blob it created" do
      post :create, params: {
        files: [ { filename: "verification.pdf", content_type: "application/pdf", byte_size: 1_024, checksum: checksum } ]
      }, format: :json

      blob = ActiveStorage::Blob.find_signed!(json.dig("uploads", 0, "signed_id"))

      expect(blob.filename.to_s).to eq("verification.pdf")
      expect(blob.byte_size).to eq(1_024)
      expect(blob.service_name).to eq(PresignedUploadService::SERVICE_NAME.to_s)
    end

    it "refuses a content type outside the allowlist" do
      post :create, params: {
        files: [ { filename: "installer.exe", content_type: "application/x-msdownload", byte_size: 1_024, checksum: checksum } ]
      }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to eq(I18n.t("activities.document_uploads.new.errors.unsupported_type"))
    end

    it "refuses a file over the upload limit" do
      post :create, params: {
        files: [
          {
            filename: "verification.pdf",
            content_type: "application/pdf",
            byte_size: PresignedUploadService::MAX_UPLOAD_BYTES + 1
          }
        ]
      }, format: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to eq(
        I18n.t(
          "activities.document_uploads.new.errors.too_large",
          limit: ActiveSupport::NumberHelper.number_to_human_size(PresignedUploadService::MAX_UPLOAD_BYTES)
        )
      )
    end

    it "creates no blobs when one file in the batch is unacceptable" do
      expect {
        post :create, params: {
          files: [
            { filename: "verification.pdf", content_type: "application/pdf", byte_size: 1_024, checksum: checksum },
            { filename: "installer.exe", content_type: "application/x-msdownload", byte_size: 1_024, checksum: checksum }
          ]
        }, format: :json
      }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "mints nothing without a flow session" do
      session.delete(:flow_id)

      expect {
        post :create, params: {
          files: [ { filename: "verification.pdf", content_type: "application/pdf", byte_size: 1_024, checksum: checksum } ]
        }, format: :json
      }.not_to change(ActiveStorage::Blob, :count)

      expect(response).not_to have_http_status(:ok)
    end
  end
end
