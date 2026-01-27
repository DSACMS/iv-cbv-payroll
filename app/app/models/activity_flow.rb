class ActivityFlow < Flow
  belongs_to :cbv_applicant
  belongs_to :identity, optional: true
  belongs_to :activity_flow_invitation, optional: true

  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  has_many :education_activities, dependent: :destroy
  has_many :payroll_accounts, as: :flow, dependent: :destroy

  before_create :set_default_reporting_window

  def self.create_from_invitation(invitation, device_id, params = {})
    create(
      activity_flow_invitation: invitation,
      cbv_applicant: invitation.cbv_applicant || CbvApplicant.create(client_agency_id: invitation.client_agency_id),
      device_id: device_id,
      **flow_attributes_from_params(params)
    )
  end

  def self.flow_attributes_from_params(params)
    reporting_window_type = params[:reporting_window] == "renewal" ? "renewal" : "application"
    { reporting_window_type: reporting_window_type }
  end

  def reporting_window_range
    current_month_start = created_at.to_date.beginning_of_month
    end_date = current_month_start - 1.day
    start_date = current_month_start - reporting_window_months.months

    start_date..end_date
  end

  def reporting_window_display
    range = reporting_window_range
    start_display = I18n.l(range.begin, format: :month_year)
    end_display = I18n.l(range.end, format: :month_year)

    return start_display if start_display == end_display

    "#{start_display} - #{end_display}"
  end

  def complete?
    completed_at.present?
  end

  def invitation_id
    activity_flow_invitation_id
  end

  private

  def set_default_reporting_window
    self.reporting_window_months ||= calculate_reporting_window_months
  end

  def calculate_reporting_window_months
    return 6 if reporting_window_type == "renewal"

    client_agency = Rails.application.config.client_agencies[cbv_applicant&.client_agency_id]
    client_agency&.application_reporting_months || 1
  end
end
