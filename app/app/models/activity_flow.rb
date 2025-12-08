class ActivityFlow < ApplicationRecord
  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  belongs_to :cbv_applicant

  has_secure_token :token, length: 10

  def self.create_with_token(reference_id: nil, client_agency_id: "sandbox")
    create!(
      cbv_applicant: CbvApplicant.create!(client_agency_id: client_agency_id),
      reference_id: reference_id
    )
  end
end
