module Activities
  class PresignedUploadsController < Activities::BaseController
    def create
      uploads = PresignedUploadService
        .new(client_agency: current_agency, authenticity_token: form_authenticity_token)
        .call(requested_uploads)

      render json: { uploads: uploads }
    rescue PresignedUploadService::UnacceptableUpload => e
      render json: {
        error: helpers.document_upload_error_message(current_agency, e.reason)
      }, status: :unprocessable_content
    end

    private

    def requested_uploads
      params
        .expect(files: [ [ :filename, :content_type, :byte_size, :checksum ] ])
        .map { |file| file.to_h.symbolize_keys }
    end
  end
end
