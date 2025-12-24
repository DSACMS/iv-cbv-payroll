class ActivityFlow < Flow
  belongs_to :cbv_applicant
  belongs_to :identity, optional: true
  belongs_to :activity_flow_invitation, optional: true

  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  has_many :education_activities, -> { where(confirmed: true) }, dependent: :destroy
  has_many :payroll_accounts, as: :flow, dependent: :destroy

  before_create :set_default_reporting_month

  def self.create_from_invitation(invitation, device_id)
    create(
      activity_flow_invitation: invitation,
      cbv_applicant: invitation.cbv_applicant || CbvApplicant.create(client_agency_id: invitation.client_agency_id),
      device_id: device_id,
      reporting_month: invitation.reporting_month
    )
  end

  def reporting_month_range
    reporting_month.beginning_of_month..reporting_month.end_of_month
  end

  def reporting_month_display
    return nil unless reporting_month

    I18n.l(reporting_month, format: :month_year)
  end

  private

  def set_default_reporting_month
    self.reporting_month ||= Date.current.beginning_of_month
  end

  def complete?
    completed_at.present?
  end

  def invitation_id
    activity_flow_invitation_id
  end
end
