class ActivityFlowInvitation < ApplicationRecord
  SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES = %w[volunteering].freeze

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

    unless pre_populated_activities.is_a?(Array)
      errors.add(:pre_populated_activities, "must be an array")
      return
    end

    pre_populated_activities.each_with_index do |entry, idx|
      unless entry.is_a?(Hash)
        errors.add("pre_populated_activities[#{idx}]", "must be an object")
        next
      end

      type = entry["type"] || entry[:type]
      unless SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES.include?(type.to_s)
        errors.add("pre_populated_activities[#{idx}].type", "must be one of #{SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES.join(', ')}")
        next
      end

      organization_name = entry["organization_name"] || entry[:organization_name]
      if organization_name.blank?
        errors.add("pre_populated_activities[#{idx}].organization_name", "can't be blank")
      end
    end
  end

  def pre_populated_activity_months_in_window
    return if pre_populated_activities.blank?
    return unless pre_populated_activities.is_a?(Array)
    return if client_agency_id.blank?

    range = ActivityFlow.expected_reporting_window_range(
      client_agency_id,
      reference_date: created_at&.to_date || Date.current
    )

    pre_populated_activities.each_with_index do |entry, idx|
      next unless entry.is_a?(Hash)
      months = entry["months"] || entry[:months]
      next unless months.is_a?(Array)

      months.each_with_index do |month_entry, m_idx|
        next unless month_entry.is_a?(Hash)
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
    return value if value.is_a?(Date)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
