module MoneyHelper
  def format_hours(hour)
    return hour unless Float(hour, exception: false).present?
    hour.to_f.round(1)
  end
end
