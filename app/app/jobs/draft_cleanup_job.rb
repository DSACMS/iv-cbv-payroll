class DraftCleanupJob < ApplicationJob
  CUTOFF = 24.hours

  def perform
    cutoff = CUTOFF.ago
    [ VolunteeringActivity, JobTrainingActivity, EmploymentActivity, EducationActivity ].each do |klass|
      klass.where(draft: true, created_at: ...cutoff).destroy_all
    end
    PayrollAccount.where(draft: true, created_at: ...cutoff).destroy_all
  end
end
