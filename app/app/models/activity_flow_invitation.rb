class ActivityFlowInvitation < ApplicationRecord
  SUPPORTED_PRE_POPULATED_ACTIVITY_TYPES = %w[volunteering].freeze

  belongs_to :cbv_applicant, optional: true
  has_many :activity_flows

  has_secure_token :auth_token, length: 10

  validate :pre_populated_activities_shape

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
end
