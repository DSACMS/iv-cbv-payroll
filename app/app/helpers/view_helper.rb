module ViewHelper
  def format_active_locale(locale_string)
    link_classes = "usa-nav__link"
    if locale_string.to_sym == I18n.locale
      link_classes = "#{link_classes} usa-current"
    end
    link_to t("shared.languages.#{locale_string}"), root_path(locale: locale_string), class: link_classes
  end

  def format_date(timestamp_string)
    begin
      Time.parse(timestamp_string).strftime("%B %d, %Y")
    rescue => e
      "Invalid timestamp"
      timestamp_string
    end
  end

  def format_view_datetime(timestamp_string)
    begin
      formatted_time = Time.parse(timestamp_string).strftime("%B %d, %Y")
      raw_timestamp = Time.parse(timestamp_string).strftime("%I:%M %p %Z")
      "#{formatted_time} - #{raw_timestamp}"
    rescue => e
      "Invalid timestamp"
    end
  end
end
