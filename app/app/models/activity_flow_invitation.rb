class ActivityFlowInvitation < ApplicationRecord
  ACTIVITY_TYPES = {
    "volunteering" => VolunteeringActivity,
    "employment" => EmploymentActivity,
    "education" => EducationActivity,
    "job_training" => JobTrainingActivity
  }.freeze

  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows
  has_one :household_member

  has_secure_token :auth_token, length: 10

  validate :pre_populated_activities_shape
  validate :pre_populated_activity_months_in_window

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.activities_flow_start_url(token: auth_token, host: host, **url_params)
  end

  def expired?
    false
  end

  def supported_pre_populated_types
    agency = Rails.application.config.client_agencies[client_agency_id]
    ACTIVITY_TYPES.select { |_type, klass| agency&.activity_types&.[](klass.display_name) }.keys
  end

  def pre_populated_hub_activity_types
    pre_populated_activities
      .filter_map { |e| ACTIVITY_TYPES[(e["type"] || e[:type]).to_s]&.display_name }
      .uniq
  end

  private

  def pre_populated_activities_shape
    return if pre_populated_activities.blank?

    pre_populated_activities.each_with_index do |entry, idx|
      type = entry["type"] || entry[:type]
      unless supported_pre_populated_types.include?(type.to_s)
        errors.add("pre_populated_activities[#{idx}].type", "must be one of #{supported_pre_populated_types.join(', ')}")
        next
      end

      ACTIVITY_TYPES[type.to_s]::PRE_POPULATED_REQUIRED_FIELDS.each do |field|
        value = entry[field] || entry[field.to_sym]
        if value.blank?
          errors.add("pre_populated_activities[#{idx}].#{field}", "can't be blank")
        end
      end
    end
  end

  def pre_populated_activity_months_in_window
    return if pre_populated_activities.blank?
    return if client_agency_id.blank?

    range = ActivityFlow.expected_reporting_window_range(
      client_agency_id,
      reference_date: created_at&.to_date || Date.current
    )

    pre_populated_activities.each_with_index do |entry, idx|
      months = entry["months"] || entry[:months]
      next if months.blank?

      months.each_with_index do |month_entry, m_idx|
        raw = month_entry["month"] || month_entry[:month]
        parsed = parse_month_date(raw)

        if parsed.nil?
          errors.add("pre_populated_activities[#{idx}].months[#{m_idx}].month", "must be a valid date")
        elsif !range.cover?(parsed)
          errors.add(
            "pre_populated_activities[#{idx}].months[#{m_idx}].month",
            "must fall within reporting window #{range.begin.iso8601}..#{range.end.iso8601}"
          )
        end
      end
    end
  end

  def parse_month_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
