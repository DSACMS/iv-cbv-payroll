class ActivityFlow < Flow
  belongs_to :cbv_applicant
  belongs_to :identity, optional: true
  belongs_to :activity_flow_invitation, optional: true

  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  has_many :education_activities, dependent: :destroy
  has_many :payroll_accounts, as: :flow, dependent: :destroy
  has_many :activity_flow_monthly_summaries, dependent: :destroy

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

  def reporting_months
    reporting_window_months.times.map { |i| reporting_window_range.begin + i.months }
  end

  def within_reporting_window?(start_date, end_date)
    start_date <= reporting_window_range.max && end_date >= reporting_window_range.min
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

  def any_activities_added?
    education_activities.where.associated(:nsc_enrollment_terms).exists? ||
      volunteering_activities.exists? ||
      job_training_activities.exists? ||
      payroll_accounts.exists?
  end

  def invitation_id
    activity_flow_invitation_id
  end

  def after_payroll_sync_succeeded(payroll_account, report)
    ActivityFlowMonthlySummary.upsert_from_report(activity_flow: self, payroll_account: payroll_account, report: report)
    touch
  end

  def monthly_summaries_by_account_with_fallback
    ActivityFlowMonthlySummary.by_account_with_fallback(activity_flow: self)
  end

  # Used by webhooks to check sync completion
  # API uses reporting_window_range for the actual dates
  def aggregator_lookback_days
    days = reporting_window_range.to_a.size
    { w2: days, gig: days }
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
