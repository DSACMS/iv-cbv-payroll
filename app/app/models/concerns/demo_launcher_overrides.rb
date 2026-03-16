module DemoLauncherOverrides
  extend ActiveSupport::Concern

  def shift_reporting_window_start!(date_str)
    start_date = Date.parse(date_str).beginning_of_month
    anchor = start_date + reporting_window_months.months
    update_columns(created_at: anchor.beginning_of_day)
  end
end
