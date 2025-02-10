class CbvFlow < ApplicationRecord
  has_many :pinwheel_accounts, dependent: :destroy
  belongs_to :cbv_flow_invitation, optional: true
  belongs_to :cbv_applicant, optional: true
  validates :site_id, inclusion: Rails.application.config.sites.site_ids

  accepts_nested_attributes_for :cbv_applicant

  scope :incomplete, -> { where(confirmation_code: nil) }

  include Redactable
  has_redactable_fields(
    case_number: :string,
    pinwheel_end_user_id: :uuid,
    additional_information: :object
  )

  def complete?
    confirmation_code.present?
  end

  def self.create_from_invitation(cbv_flow_invitation)
    create(
      cbv_flow_invitation: cbv_flow_invitation,
      cbv_applicant: cbv_flow_invitation.cbv_applicant,
      site_id: cbv_flow_invitation.site_id,
    )
  end

  def has_account_with_required_data?
    pinwheel_accounts.any?(&:has_required_data?)
  end
end
