namespace :data_deletion do
  desc "Redact data that is older than our retention policy"
  task redact_all: :environment do
    service = DataRetentionService.new
    service.redact_all!
  end

  desc "Delete uploaded documents for delivered reports past the retention window"
  task delete_delivered_documents: :environment do
    DataRetentionService.new.delete_delivered_documents
  end
end
