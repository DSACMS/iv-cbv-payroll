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

  def format_date_range(start_date, end_date)
    return unless start_date && end_date

    start_formatted = format_date(start_date, :long)
    end_formatted = format_date(end_date, :long)

    if I18n.locale == :es
      "#{start_formatted} al #{end_formatted}"
    else
      "#{start_formatted} to #{end_formatted}"
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
end
