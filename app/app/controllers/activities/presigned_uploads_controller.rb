module Activities
  class PresignedUploadsController < Activities::BaseController
    def create
      uploads = PresignedUploadService
        .new(authenticity_token: form_authenticity_token)
        .call(requested_uploads)

      render json: { uploads: uploads }
    rescue PresignedUploadService::UnacceptableUpload => e
      render json: { error: error_message(e.reason) }, status: :unprocessable_entity
    end

    private

    def requested_uploads
      params
        .expect(files: [ [ :filename, :content_type, :byte_size, :checksum ] ])
        .map { |file| file.to_h.symbolize_keys }
    end

    # i18n-tasks-use t('activities.document_uploads.new.errors.empty')
    # i18n-tasks-use t('activities.document_uploads.new.errors.too_large')
    # i18n-tasks-use t('activities.document_uploads.new.errors.unsupported_type')
    def error_message(reason)
      t(
        "activities.document_uploads.new.errors.#{reason}",
        limit: helpers.number_to_human_size(PresignedUploadService::MAX_UPLOAD_BYTES)
      )
    end
  end
end
