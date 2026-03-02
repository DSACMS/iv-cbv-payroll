require "rails_helper"

RSpec.describe JobTrainingActivityMonth, type: :model do
  it_behaves_like "an activity month model",
    parent_factory: :job_training_activity,
    month_factory: :job_training_activity_month,
    parent_association: :job_training_activity
end
