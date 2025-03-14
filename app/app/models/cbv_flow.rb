class CbvFlow < ApplicationRecord
  has_many :payroll_accounts, dependent: :destroy
  belongs_to :cbv_flow_invitation, optional: true
  belongs_to :cbv_applicant, optional: true
  validates :client_agency_id, inclusion: Rails.application.config.client_agencies.client_agency_ids

  accepts_nested_attributes_for :cbv_applicant

  scope :incomplete, -> { where(confirmation_code: nil) }

  include Redactable
  has_redactable_fields(
    end_user_id: :uuid,
    additional_information: :object
  )

  def complete?
    confirmation_code.present?
  end

  def self.create_from_invitation(cbv_flow_invitation)
    create(
      cbv_flow_invitation: cbv_flow_invitation,
      cbv_applicant: cbv_flow_invitation.cbv_applicant,
      client_agency_id: cbv_flow_invitation.client_agency_id,
    )
  end

  def self.create_without_invitation(client_agency_id)
    # Tom: we only had create_from_invitation to keep the logic of copying the fields in one place.
    # use create! while testing to at least make it easier to work with
    create!(
      cbv_applicant: CbvApplicant.create!(
      ), #Tom: might not even need to create this if none of the fields are useful... maybe we do that on the new page I'm adding
      client_agency_id: client_agency_id
    )
  end

  def has_account_with_required_data?
    payroll_accounts.any?(&:has_required_data?)
  end
end
