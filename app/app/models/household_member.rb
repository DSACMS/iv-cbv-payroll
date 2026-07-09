class HouseholdMember < ApplicationRecord
  belongs_to :household
  belongs_to :activity_flow_invitation

  validates :display_name, :role_label, :reference_id, presence: true
  validates :reference_id, uniqueness: { scope: :household_id }
  validates :activity_flow_invitation_id, uniqueness: true

  def completed_activity_flow?
    activity_flow_invitation.activity_flows.completed.exists?
  end
end
