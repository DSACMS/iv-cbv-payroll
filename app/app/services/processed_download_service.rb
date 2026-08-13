class ProcessedDownloadService
  SERVICE_NAME = ENV["PROCESSED_BUCKET_NAME"].present? ? :processed : :processed_local

  def initialize(service: ActiveStorage::Blob.services.fetch(SERVICE_NAME))
    @service = service
  end

  def download_file(key, destination)
    File.binwrite(destination, @service.download(key))
  end
end
