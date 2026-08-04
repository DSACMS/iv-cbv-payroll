class FakeS3UploadsController < ActionController::Base
  skip_forgery_protection

  def create
    file = params[:file]
    key = params[:key]

    return head :bad_request if file.blank? || key.blank?
    return head :bad_request if file.size > PresignedUploadService::MAX_UPLOAD_BYTES

    ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME).upload(key, file.tempfile)

    head :no_content
  end
end
