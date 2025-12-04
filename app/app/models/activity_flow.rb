class ActivityFlow < ApplicationRecord
  belongs_to :identity, optional: true
  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  belongs_to :cbv_applicant
end
