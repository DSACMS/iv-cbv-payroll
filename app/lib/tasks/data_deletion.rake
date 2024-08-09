namespace :data_deletion do
  desc "Redact data that is older than our retention policy"
  task redact_all: :environment do
    service = DataRetentionService.new
    service.redact_all!
  end
end
