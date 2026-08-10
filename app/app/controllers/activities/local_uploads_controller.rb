module Activities
  class LocalUploadsController < Activities::BaseController
    KEY_FORMAT = /\A[a-z0-9]{28}\z/

    def create
      file = params[:file]
      key = params[:key].to_s

      return head :bad_request if file.blank? || !KEY_FORMAT.match?(key)
      return head :bad_request if file.size > PresignedUploadService::MAX_UPLOAD_BYTES

      blob = ActiveStorage::Blob.find_by(key: key, service_name: PresignedUploadService::SERVICE_NAME)

      return head :bad_request if blob.nil?
      return head :bad_request unless digest_of(file) == blob.checksum

      ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME).upload(key, file.tempfile)

      head :no_content
    end

    private

    def digest_of(file)
      Digest::SHA256.file(file.tempfile.path).base64digest
    end
  end
end
