# Synchronizes data from the National Student Clearinghouse (NSC)
class NscSynchronizationJob < ApplicationJob
  queue_as :default

  after_discard do |job, exception|
    education_activity = EducationActivity.find(job.arguments.first)
    Rails.logger.error("Failed #{self.class.name} for EducationActivity ID #{education_activity.id}")
    education_activity.update(status: :failed)
  end

  def perform(education_activity_id)
    Rails.logger.info "Fetching NSC Data for EducationActivity #{education_activity_id}"

    @education_activity = EducationActivity.find(education_activity_id)
    unless @education_activity.sync_unknown?
      Rails.logger.warn "Duplicate #{self.class.name} enqueued for already-fetched EducationActivity ID #{@education_activity.id}"
    end

    nsc_service = NscDataFetcherService.new(education_activity: @education_activity)
    nsc_service.fetch
  end
end
