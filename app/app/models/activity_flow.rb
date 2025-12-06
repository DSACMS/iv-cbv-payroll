class ActivityFlow < ApplicationRecord
  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy

  has_secure_token :token, length: 10

  def self.create_with_token(reference_id: nil)
    create!(reference_id: reference_id)
  end
end
