FactoryBot.define do
  factory :education_activity_month do
    education_activity
    month { education_activity.activity_flow.reporting_window_range.begin.beginning_of_month }
    hours { 0 }
  end
end
