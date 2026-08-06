module Activities
  class LocalUploadsController < Activities::BaseController
    KEY_FORMAT = /\A[a-z0-9]{28}\z/

    def create
      file = params[:file]
      key = params[:key].to_s

      return head :bad_request if file.blank? || !KEY_FORMAT.match?(key)
      return head :bad_request if file.size > PresignedUploadService::MAX_UPLOAD_BYTES

      ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME).upload(key, file.tempfile)

      head :no_content
    end
  end
end
