class CbvFlow < ApplicationRecord
  has_many :pinwheel_accounts, dependent: :destroy
  belongs_to :cbv_flow_invitation, optional: true
  belongs_to :cbv_client, optional: true
  validates :site_id, inclusion: Rails.application.config.sites.site_ids

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
      case_number: cbv_flow_invitation.case_number,
      site_id: cbv_flow_invitation.site_id
    )
  end

  def has_account_with_required_data?
    pinwheel_accounts.any?(&:has_required_data?)
  end
end
