require "rails_helper"

RSpec.describe Activities::LocalUploadsController, type: :controller do
  include_context "activity_hub"

  let(:activity_flow) { create(:activity_flow) }
  let(:client_agency) { Rails.application.config.client_agencies[activity_flow.cbv_applicant.client_agency_id] }
  let(:service) { ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME) }
  let(:body) { "%PDF-1.4" }
  let(:json) { response.parsed_body }

  let(:presigned) do
    PresignedUploadService.new(client_agency: client_agency).call([
      {
        filename: "verification.pdf",
        content_type: "application/pdf",
        byte_size: body.bytesize,
        checksum: Digest::SHA256.base64digest(body)
      }
    ]).first
  end

  let(:key) { ActiveStorage::Blob.find_signed!(presigned[:signed_id]).key }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  def uploaded(contents, content_type: "application/pdf", filename: "verification.pdf")
    Rack::Test::UploadedFile.new(
      StringIO.new(contents),
      content_type,
      original_filename: filename
    )
  end

  def upload(contents = body, key: self.key, content_type: "application/pdf", filename: "verification.pdf", **extra)
    post :create, params: {
      key: key,
      file: uploaded(contents, content_type: content_type, filename: filename),
      **extra
    }
  end

  describe "POST #create" do
    it "stores the body at the key the policy pinned and answers 204 like S3 does" do
      upload

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(service.download(key)).to eq(body)
    end

    it "rejects a body whose digest does not match what the blob recorded" do
      upload("%PDF-9.9")

      expect(response).to have_http_status(:bad_request)
      expect(service.exist?(key)).to be(false)
    end

    it "rejects a body whose size differs from what the blob recorded" do
      contents = "%PDF-1.4 with extra bytes"
      blob = ActiveStorage::Blob.create!(
        filename: "verification.pdf",
        content_type: "application/pdf",
        byte_size: body.bytesize,
        checksum: Digest::SHA256.base64digest(contents),
        service_name: PresignedUploadService::SERVICE_NAME,
        metadata: { identified: true, analyzed: true }
      )

      upload(contents, key: blob.key)

      expect(response).to have_http_status(:bad_request)
      expect(service.exist?(blob.key)).to be(false)
    end

    it "returns a clear error for an empty body" do
      upload("")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq(I18n.t("activities.document_uploads.new.errors.empty"))
      expect(service.exist?(key)).to be(false)
    end

    it "rejects a content type that differs from the presigned blob" do
      upload(content_type: "image/png")

      expect(response).to have_http_status(:bad_request)
      expect(service.exist?(key)).to be(false)
    end

    it "returns a clear error for an incoming content type outside the agency allowlist" do
      upload(content_type: "image/heic")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq(
        I18n.t(
          "activities.document_uploads.new.errors.unsupported_type",
          types: controller.helpers.document_upload_allowed_types_sentence(client_agency)
        )
      )
      expect(service.exist?(key)).to be(false)
    end

    it "rejects a content type outside the agency allowlist" do
      blob = ActiveStorage::Blob.create!(
        filename: "photo.heic",
        content_type: "image/heic",
        byte_size: body.bytesize,
        checksum: Digest::SHA256.base64digest(body),
        service_name: PresignedUploadService::SERVICE_NAME,
        metadata: { identified: true, analyzed: true }
      )

      upload(key: blob.key, content_type: "image/heic", filename: "photo.heic")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq(
        I18n.t(
          "activities.document_uploads.new.errors.unsupported_type",
          types: controller.helpers.document_upload_allowed_types_sentence(client_agency)
        )
      )
      expect(service.exist?(blob.key)).to be(false)
    end

    it "rejects a key the server never minted" do
      upload(key: ActiveStorage::Blob.generate_unique_secure_token)

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a file over the limit the presigned policy would have enforced" do
      allow_any_instance_of(ActionDispatch::Http::UploadedFile)
        .to receive(:size).and_return(client_agency.max_document_upload_size_bytes + 1)

      upload

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq(
        I18n.t(
          "activities.document_uploads.new.errors.too_large",
          limit: ActiveSupport::NumberHelper.number_to_human_size(client_agency.max_document_upload_size_bytes)
        )
      )
      expect(service.exist?(key)).to be(false)
    end

    it "rejects a request with no file" do
      post :create, params: { key: key }

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a key that is not a storage token" do
      upload(key: "short")

      expect(response).to have_http_status(:bad_request)
    end

    it "rejects a key that tries to escape the storage root" do
      upload(key: "../../../../etc/passwd")

      expect(response).to have_http_status(:bad_request)
    end

    it "refuses to write anything without the CSRF token the presign response carries" do
      ActionController::Base.allow_forgery_protection = true

      upload

      expect(response).not_to have_http_status(:no_content)
      expect(service.exist?(key)).to be(false)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "accepts the CSRF token as a form field, since the S3 path cannot send a header" do
      ActionController::Base.allow_forgery_protection = true

      upload(authenticity_token: controller.send(:form_authenticity_token))

      expect(response).to have_http_status(:no_content)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "refuses to write anything without a flow session" do
      session.delete(:flow_id)

      upload

      expect(response).not_to have_http_status(:no_content)
      expect(service.exist?(key)).to be(false)
    end
  end
end
