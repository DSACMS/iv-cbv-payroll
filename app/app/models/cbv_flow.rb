class CbvFlow < ApplicationRecord
  has_many :payroll_accounts, dependent: :destroy
  belongs_to :cbv_flow_invitation, optional: true
  belongs_to :cbv_applicant, optional: true
  validates :client_agency_id, inclusion: Rails.application.config.client_agencies.client_agency_ids

  accepts_nested_attributes_for :cbv_applicant

  scope :incomplete, -> { where(confirmation_code: nil) }
  scope :completed, -> { where.not(confirmation_code: nil) }

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
    create(
      cbv_applicant: CbvApplicant.create(client_agency_id: client_agency_id),
      client_agency_id: client_agency_id
    )
  end

  def has_account_with_required_data?
    payroll_accounts.any?(&:sync_succeeded?)
  end

  def to_generic_url
    client_agency = Rails.application.config.client_agencies[client_agency_id]
    raise ArgumentError.new("Client Agency #{client_agency_id} not found") unless client_agency

    host = client_agency.agency_domain
    Rails.application.routes.url_helpers.cbv_flow_new_url({ client_agency_id: client_agency_id, host: host, protocol: "https", locale: I18n.locale })
  end
end
