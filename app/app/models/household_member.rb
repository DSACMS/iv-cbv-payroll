class HouseholdMember < ApplicationRecord
  belongs_to :household
  belongs_to :activity_flow_invitation
  has_many :activity_flows, through: :activity_flow_invitation
  has_many :completed_activity_flows, -> { completed }, through: :activity_flow_invitation, source: :activity_flows

  validates :display_name, :role_label, :reference_id, presence: true
  validates :reference_id, uniqueness: { scope: :household_id }
  validates :activity_flow_invitation_id, uniqueness: true

  def completed_activity_flow?
    completed_activity_flows.any?
  end
end
