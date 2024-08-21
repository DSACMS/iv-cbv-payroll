module ViewHelper
  DATE_FORMAT = "%B %d, %Y"

  def format_active_locale(locale_string)
    link_classes = "usa-nav__link"
    if locale_string.to_sym == I18n.locale
      link_classes = "#{link_classes} usa-current"
    end
    link_to t("shared.languages.#{locale_string}"), root_path(locale: locale_string), class: link_classes
  end

  def format_parsed_date(date)
    begin
      date.strftime(DATE_FORMAT)
    rescue => e
      date
    end
  end

  def format_date(timestamp_string)
    begin
      Time.parse(timestamp_string).strftime(DATE_FORMAT)
    rescue => e
      "Invalid timestamp"
      timestamp_string
    end
  end

  def format_view_datetime(timestamp_string)
    begin
      formatted_time = Time.parse(timestamp_string).strftime(DATE_FORMAT)
      raw_timestamp = Time.parse(timestamp_string).strftime("%I:%M %p %Z")
      "#{formatted_time} - #{raw_timestamp}"
    rescue => e
      "Invalid timestamp"
    end
  end

  def format_money(dollars_in_cents)
    number_to_currency(dollars_in_cents.to_f / 100)
  end
end
