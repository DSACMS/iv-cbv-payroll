class JobTrainingActivityMonth < ApplicationRecord
  belongs_to :job_training_activity

  validates :month, presence: true
  validates :hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
