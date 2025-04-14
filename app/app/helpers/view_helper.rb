module ViewHelper
  DATE_FORMAT = "%B %d, %Y"

  def switch_locale_link(locale)
    new_locale = locale == I18n.default_locale ? nil : locale
    path = url_for(request.params.merge(locale: new_locale))
    link_to t("shared.languages.#{locale}"), path, class: "usa-nav__link", data: { "turbo-prefetch": false }
  end

  def format_parsed_date(date, format = :default)
    return unless date
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

  def format_view_datetime(timestamp_string)
    begin
      parsed_time = Time.parse(timestamp_string)
      formatted_date = I18n.l(parsed_time.to_date, format: :long)
      formatted_time = I18n.l(parsed_time, format: :time)
      "#{formatted_date} - #{formatted_time}"
    end
  rescue => e
    "Invalid timestamp"
  end

  def format_money(dollars_in_cents)
    number_to_currency(dollars_in_cents.to_f / 100)
  end

  def translate_aggregator_value(namespace, value)
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
