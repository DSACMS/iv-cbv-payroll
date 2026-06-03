class ActivityFlowInvitation < ApplicationRecord
  SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES = %w[volunteering employment education].freeze
  PRE_POPULATED_NAME_FIELDS = {
    "volunteering" => "organization_name",
    "employment" => "employer_name",
    "education" => "school_name"
  }.freeze

  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows

  has_secure_token :auth_token, length: 10

  validate :pre_populated_activities_shape
  validate :pre_populated_activity_months_in_window

  def to_url(host: ENV.fetch("DOMAIN_NAME", "localhost"), **url_params)
    Rails.application.routes.url_helpers.activities_flow_start_url(token: auth_token, host: host, **url_params)
  end

  def expired?
    false
  end

  private

  def pre_populated_activities_shape
    return if pre_populated_activities.blank?

    pre_populated_activities.each_with_index do |entry, idx|
      type = entry["type"] || entry[:type]
      unless SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES.include?(type.to_s)
        errors.add("pre_populated_activities[#{idx}].type", "must be one of #{SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES.join(', ')}")
        next
      end

      name_field = PRE_POPULATED_NAME_FIELDS[type.to_s]
      name = entry[name_field] || entry[name_field.to_sym]
      if name.blank?
        errors.add("pre_populated_activities[#{idx}].#{name_field}", "can't be blank")
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
