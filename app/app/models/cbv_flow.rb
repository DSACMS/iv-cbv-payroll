class CbvFlow < Flow
  belongs_to :cbv_flow_invitation, optional: true
  belongs_to :cbv_applicant, optional: true

  scope :incomplete, -> { where(confirmation_code: nil) }
  scope :completed, -> { where.not(confirmation_code: nil) }

  include Redactable
  has_redactable_fields(
    end_user_id: :uuid
  )

  def complete?
    confirmation_code.present?
  end

  def invitation_id
    cbv_flow_invitation_id
  end

  def self.create_from_invitation(cbv_flow_invitation, device_id, _params = {})
    create(
      cbv_flow_invitation: cbv_flow_invitation,
      cbv_applicant: cbv_flow_invitation.cbv_applicant,
      device_id: device_id
    )
  end

  def to_generic_url(origin: nil)
    client_agency = Rails.application.config.client_agencies[cbv_applicant.client_agency_id]
    raise ArgumentError.new("Client Agency #{cbv_applicant.client_agency_id} not found") unless client_agency

    url_params = {
      host: client_agency.agency_domain,
      protocol: (client_agency.agency_domain.nil? || client_agency.agency_domain == "localhost") ? "http" : "https",
      locale: I18n.locale
    }
    url_params[:origin] = origin if origin.present?

    if client_agency.agency_domain.present?
      Rails.application.routes.url_helpers.root_url(url_params.compact)
    else
      url_params[:client_agency_id] = cbv_applicant.client_agency_id
      Rails.application.routes.url_helpers.cbv_flow_new_url(url_params.compact)
    end
  end
end
