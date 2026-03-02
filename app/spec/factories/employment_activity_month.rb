FactoryBot.define do
  factory :employment_activity_month do
    employment_activity
    month { employment_activity.activity_flow.reporting_months.first.beginning_of_month }
    hours { 20 }
    gross_income { 339 }
  end
end
