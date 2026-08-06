require "rails_helper"

RSpec.describe Activities::LocalUploadsController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) { create(:activity_flow) }
  let(:service) { ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME) }
  let(:key) { ActiveStorage::Blob.generate_unique_secure_token }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  def pdf(size: 8)
    Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-1.4".ljust(size, " ")),
      "application/pdf",
      original_filename: "verification.pdf"
    )
  end

  describe "POST #create" do
    it "stores the body at the key the policy pinned and answers 204 like S3 does" do
      post :create, params: { key: key, file: pdf }

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(service.download(key)).to eq("%PDF-1.4")
    end

    it "rejects a file over the limit the presigned policy would have enforced" do
      post :create, params: { key: key, file: pdf(size: PresignedUploadService::MAX_UPLOAD_BYTES + 1) }

      expect(response).to have_http_status(:bad_request)
      expect(service.exist?(key)).to be(false)
    end

    it "rejects a request with no file" do
      post :create, params: { key: key }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a key that is not a storage token" do
      post :create, params: { key: "short", file: pdf }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a key that tries to escape the storage root" do
      post :create, params: { key: "../../../../etc/passwd", file: pdf }

      expect(response).to have_http_status(:bad_request)
    end

    it "refuses to write anything without a flow session" do
      session.delete(:flow_id)

      post :create, params: { key: key, file: pdf }

      expect(response).not_to have_http_status(:no_content)
      expect(service.exist?(key)).to be(false)
    end
  end
end
