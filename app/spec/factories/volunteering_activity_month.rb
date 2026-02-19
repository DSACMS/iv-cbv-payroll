FactoryBot.define do
  factory :volunteering_activity_month do
    volunteering_activity
    month { volunteering_activity.activity_flow.reporting_window_range.begin.beginning_of_month }
    hours { 0 }
  end
end
