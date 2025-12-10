class ActivityFlow < ApplicationRecord
  belongs_to :cbv_applicant
  belongs_to :identity, optional: true
  belongs_to :activity_flow_invitation, optional: true

  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  has_many :education_activities, -> { where(confirmed: true) }, dependent: :destroy

  def self.create_from_invitation(invitation, device_id)
    create(
      activity_flow_invitation: invitation,
      cbv_applicant: invitation.cbv_applicant || CbvApplicant.create(client_agency_id: invitation.client_agency_id),
      device_id: device_id
    )
  end
end
