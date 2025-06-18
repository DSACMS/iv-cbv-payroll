module ReportViewHelper
  def format_hours(hour)
    return hour unless Float(hour, exception: false).present?
    hour.to_f.round(1)
  end

  def federal_cents_per_mile(year)
    case year
    when 2024
      67
    else
      70
    end
  end

  # Default format is Month Day, Year (e.g. January 1, 2020)
  def format_parsed_date(date, format = :long)
    I18n.l(date.to_date, format: format)
  end

  def format_date(timestamp_string, format = :long)
    begin
      parsed_time = timestamp_string.is_a?(String) ? Time.parse(timestamp_string) : timestamp_string
      I18n.l(parsed_time.to_date, format: format)
    rescue
      timestamp_string
    end
  end

  def format_money(dollars_in_cents)
    number_to_currency(dollars_in_cents.to_f / 100)
  end

  def format_boolean(boolean_value)
    case boolean_value
    when true, "true"
      I18n.t("us_form_with.boolean_true")
    when false, "false"
      I18n.t("us_form_with.boolean_false")
    when nil
      I18n.t("shared.not_applicable")
    else
      raise ArgumentError, "format_boolean only accepts true, false, 'true', 'false', or nil. Got: #{boolean_value.inspect}"
    end
  end

  def report_data_range(report)
    case report.fetched_days
    when 90
      t("shared.report_data_range.ninety_days")
    when 182
      t("shared.report_data_range.six_months")
    else
      raise "Missing i18n key in `shared.report_data_range` for report.fetched_days = #{report.fetched_days}"
    end
  end

  def translate_aggregator_value(namespace, value)
    return unless value.present?

    i18n_key = "aggregator_strings.#{namespace}.#{value}"

    # convert the key to snake_case, replacing hyphens with underscores
    i18n_key = i18n_key.gsub("-", "_").downcase

    if I18n.exists?(i18n_key)
      I18n.t(i18n_key)
    elsif I18n.locale == :en
      # if the key isn't in spanish, just return the original value
      value
    else
      if Rails.env.development? || Rails.env.test?
        raise "Missing aggregator translation for #{namespace}.#{value}"
      end

      # In production, log warning and return original value
      Rails.logger.warn "Unknown aggregator value for #{namespace}: #{value}"

      value
    end
  end
end
