class ActivityFlow < ApplicationRecord
  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
end
