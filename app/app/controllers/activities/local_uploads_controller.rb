module Activities
  class LocalUploadsController < Activities::BaseController
    KEY_FORMAT = /\A[a-z0-9]{28}\z/

    def create
      file = params[:file]
      key = params[:key].to_s

      return head :bad_request if file.blank? || !KEY_FORMAT.match?(key)
      return render_upload_error(:empty) unless file.size.positive?
      return render_upload_error(:too_large) if file.size > current_agency.max_document_upload_size_bytes

      blob = ActiveStorage::Blob.find_by(key: key, service_name: PresignedUploadService::SERVICE_NAME)

      return head :bad_request if blob.nil?
      return render_upload_error(:unsupported_type) unless current_agency.allowed_document_content_types.include?(blob.content_type)
      return render_upload_error(:unsupported_type) unless current_agency.allowed_document_content_types.include?(file.content_type)
      return head :bad_request unless file.content_type == blob.content_type
      return head :bad_request unless file.size == blob.byte_size
      return head :bad_request unless digest_of(file) == blob.checksum

      ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME).upload(key, file.tempfile)

      head :no_content
    end

    private

    def render_upload_error(reason)
      render json: {
        error: helpers.document_upload_error_message(current_agency, reason)
      }, status: :unprocessable_content
    end

    def digest_of(file)
      Digest::SHA256.file(file.tempfile.path).base64digest
    end
  end
end
