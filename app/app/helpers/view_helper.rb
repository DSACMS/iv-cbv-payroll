module ViewHelper
  DATE_FORMAT = "%B %d, %Y"

  def format_active_locale(locale_string)
    # using request.fullpath to include query parameters so that
    # switching languages doesn't lose the query parameters
    current_path = request.fullpath.sub(/\A\/#{I18n.locale}/, "")
    new_path = "/#{locale_string}#{current_path}"
    link_to t("shared.languages.#{locale_string}"), new_path, class: "usa-nav__link"
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
