require "rails_helper"

RSpec.describe "FakeS3Uploads", type: :request do
  let(:service) { ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME) }
  let(:key) { ActiveStorage::Blob.generate_unique_secure_token }

  def upload(file, key: self.key)
    post fake_s3_uploads_path, params: { key: key, file: file }.compact
  end

  def pdf(size: 8)
    Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-1.4".ljust(size, " ")),
      "application/pdf",
      original_filename: "verification.pdf"
    )
  end

  it "stores the body at the key the policy pinned and answers 204 like S3 does" do
    upload(pdf)

    expect(response).to have_http_status(:no_content)
    expect(response.body).to be_empty
    expect(service.download(key)).to eq("%PDF-1.4")
  end

  it "rejects a file over the limit the presigned policy would have enforced" do
    upload(pdf(size: PresignedUploadService::MAX_UPLOAD_BYTES + 1))

    expect(response).to have_http_status(:bad_request)
    expect(service.exist?(key)).to be(false)
  end

  it "rejects a request with no file" do
    upload(nil)

    expect(response).to have_http_status(:bad_request)
  end

  it "rejects a request with no key" do
    upload(pdf, key: nil)

    expect(response).to have_http_status(:bad_request)
  end

  it "accepts uploads with no CSRF token, since S3 would not receive one" do
    ActionController::Base.allow_forgery_protection = true

    upload(pdf)

    expect(response).to have_http_status(:no_content)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "accepts uploads with no flow session, since S3 would not have one" do
    upload(pdf)

    expect(response).to have_http_status(:no_content)
    expect(response).not_to be_redirect
  end
end
