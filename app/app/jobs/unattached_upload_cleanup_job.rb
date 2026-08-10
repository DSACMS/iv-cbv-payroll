class UnattachedUploadCleanupJob < ApplicationJob
  CUTOFF = 24.hours

  def perform
    ActiveStorage::Blob
      .unattached
      .where(service_name: PresignedUploadService::SERVICE_NAME, created_at: ...CUTOFF.ago)
      .destroy_all
  end
end
