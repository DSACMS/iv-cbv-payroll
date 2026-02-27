FactoryBot.define do
  factory :job_training_activity_month do
    job_training_activity
    month { job_training_activity.activity_flow.reporting_window_range.begin.beginning_of_month }
    hours { 0 }
  end
end
