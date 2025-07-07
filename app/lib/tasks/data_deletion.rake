namespace :data_deletion do
  desc "Redact data that is older than our retention policy"
  task redact_all: :environment do
    service = DataRetentionService.new
    service.redact_all!
  end

  desc "clear background jobs older than expiration days"
  task clear_old_background_jobs: :environment do
  	SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)
  end
end


