class ActivityFlow < Flow
  include DemoLauncherOverrides

  DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS = 6
  DEFAULT_APPLICATION_REPORTING_WINDOW_MONTHS = 1

  belongs_to :cbv_applicant
  belongs_to :identity, optional: true
  belongs_to :activity_flow_invitation, optional: true

  has_many :volunteering_activities, dependent: :destroy
  has_many :job_training_activities, dependent: :destroy
  has_many :education_activities, dependent: :destroy
  has_many :employment_activities, dependent: :destroy
  has_many :payroll_accounts, as: :flow, dependent: :destroy
  has_many :activity_flow_monthly_summaries, dependent: :destroy
  has_many :activity_flow_employment_summaries, dependent: :destroy

  before_create :set_default_reporting_window, :set_default_renewal_required_months

  scope :incomplete, -> { where(completed_at: nil) }

  def self.create_from_invitation(invitation, device_id, params = {})
    flow = create(
      activity_flow_invitation: invitation,
      cbv_applicant: invitation.cbv_applicant || CbvApplicant.create(client_agency_id: invitation.client_agency_id),
      device_id: device_id,
      **flow_attributes_from_params(params)
    )

    hydrate_pre_populated_activities!(flow, invitation) if flow.persisted?

    flow
  end

  def self.resume_or_create_from_invitation(invitation, device_id, params = {})
    invitation.activity_flows.incomplete.order(created_at: :desc).first ||
      create_from_invitation(invitation, device_id, params)
  end

  def self.hydrate_pre_populated_activities!(flow, invitation)
    entries = invitation.pre_populated_activities
    return if entries.empty?

    entries.each do |entry|
      attrs = entry.stringify_keys
      case attrs["type"].to_s
      when "volunteering"
        next if flow.volunteering_activities.exists?

        activity = flow.volunteering_activities.create(
          attrs.slice(*VolunteeringActivity::FIELDS)
            .merge("draft" => true, "pre_populated" => true)
        )
        next unless activity.persisted?

        Array(attrs["months"]).each do |month_entry|
          activity.volunteering_activity_months.create(month_entry.stringify_keys.slice(*VolunteeringActivityMonth::FIELDS))
        end
      when "employment"
        next if flow.employment_activities.exists?

        activity = flow.employment_activities.create(
          attrs.slice(*EmploymentActivity::FIELDS)
            .merge("draft" => true, "pre_populated" => true)
        )
        next unless activity.persisted?

        Array(attrs["months"]).each do |month_entry|
          activity.employment_activity_months.create(month_entry.stringify_keys.slice(*EmploymentActivityMonth::FIELDS))
        end
      when "education"
        next if flow.education_activities.exists?

        activity = flow.education_activities.create(
          attrs.slice(*EducationActivity::FIELDS)
            .merge("draft" => true, "data_source" => "fully_self_attested", "pre_populated" => true)
        )
        next unless activity.persisted?

        Array(attrs["months"]).each do |month_entry|
          activity.education_activity_months.create(month_entry.stringify_keys.slice(*EducationActivityMonth::FIELDS))
        end
      when "job_training"
        next if flow.job_training_activities.exists?

        activity = flow.job_training_activities.create(
          attrs.slice(*JobTrainingActivity::FIELDS)
            .merge("draft" => true, "pre_populated" => true)
        )
        next unless activity.persisted?

        Array(attrs["months"]).each do |month_entry|
          activity.job_training_activity_months.create(month_entry.stringify_keys.slice(*JobTrainingActivityMonth::FIELDS))
        end
      end
    end
  end

  def self.flow_attributes_from_params(params)
    reporting_window_type = params[:reporting_window] == "renewal" ? "renewal" : "application"
    { reporting_window_type: reporting_window_type }
  end

  # Reporting window an ActivityFlow would have if created on `reference_date`
  # for the given agency. Used by both the instance method and by
  # ActivityFlowInvitation validation (which runs before the flow exists).
  def self.expected_reporting_window_range(client_agency_id, reporting_window_type: "application", reference_date: Date.current, months_override: nil)
    months = months_override || (
      if reporting_window_type == "renewal"
        DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS
      else
        Rails.application.config.client_agencies[client_agency_id]&.application_reporting_months || DEFAULT_APPLICATION_REPORTING_WINDOW_MONTHS
      end
    )
    current_month_start = reference_date.to_date.beginning_of_month
    end_date = current_month_start - 1.day
    start_date = current_month_start - months.months
    start_date..end_date
  end

  def reporting_window_range
    self.class.expected_reporting_window_range(
      cbv_applicant&.client_agency_id,
      reporting_window_type: reporting_window_type,
      reference_date: created_at,
      months_override: reporting_window_months
    )
  end

  def reporting_months
    reporting_window_months.times.map { |i| reporting_window_range.begin + i.months }
  end

  def within_reporting_window?(start_date, end_date)
    start_date <= reporting_window_range.max && end_date >= reporting_window_range.min
  end

  def reporting_window_display
    range = reporting_window_range
    end_display = I18n.l(range.end, format: :month_year)

    return end_display if reporting_window_months == 1

    if range.begin.year == range.end.year
      start_display = I18n.l(range.begin, format: :month)
    else
      start_display = I18n.l(range.begin, format: :month_year)
    end

    "#{start_display} - #{end_display}"
  end

  def any_activities_added?
    volunteering_activities.published.exists? ||
      job_training_activities.published.exists? ||
      education_activities.published.exists? ||
      employment_activities.published.exists? ||
      payroll_accounts.published.exists?
  end

  def complete?
    completed_at.present?
  end

  def invitation_id
    activity_flow_invitation_id
  end

  def after_payroll_sync_succeeded(payroll_account, report)
    ActivityFlowEmploymentSummary.persist_from_report(activity_flow: self, payroll_account: payroll_account, report: report)
    ActivityFlowMonthlySummary.upsert_from_report(activity_flow: self, payroll_account: payroll_account, report: report)
    touch
  end

  def monthly_summaries_by_account_with_fallback
    ActivityFlowMonthlySummary.by_account_with_fallback(activity_flow: self)
  end

  def employment_summaries_by_account_with_fallback
    ActivityFlowEmploymentSummary.by_account_with_fallback(activity_flow: self)
  end

  # Used by webhooks to check sync completion
  # API uses reporting_window_range for the actual dates
  def aggregator_lookback_days
    days = reporting_window_range.to_a.size
    { w2: days, gig: days }
  end

  def activity_month_order_oldest_first?
    true
  end

  def renewal_reporting_window?
    reporting_window_type == "renewal"
  end

  def required_month_count
    window_months = reporting_window_months || calculate_reporting_window_months
    return window_months unless renewal_reporting_window?

    renewal_required_months || window_months
  end

  def set_required_month_count!(requested_count)
    update!(renewal_required_months: requested_count)
  end

  def set_reporting_window_months!(requested_months)
    update!(reporting_window_months: requested_months.to_i)
  end

  private

  def set_default_reporting_window
    self.reporting_window_months ||= calculate_reporting_window_months
  end

  def calculate_reporting_window_months
    return DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS if renewal_reporting_window?

    client_agency = Rails.application.config.client_agencies[cbv_applicant&.client_agency_id]
    client_agency&.application_reporting_months || DEFAULT_APPLICATION_REPORTING_WINDOW_MONTHS
  end

  def set_default_renewal_required_months
    return unless renewal_reporting_window?

    client_agency = Rails.application.config.client_agencies[cbv_applicant&.client_agency_id]
    self.renewal_required_months ||= client_agency&.renewal_required_months || reporting_window_months
  end
end
