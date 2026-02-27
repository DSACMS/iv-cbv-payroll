FactoryBot.define do
  factory :job_training_activity do
    activity_flow { association(:activity_flow,
                                volunteering_activities_count: 0,
                                job_training_activities_count: 0,
                                education_activities_count: 0) }
    organization_name { "Goodwill" }
    program_name { "Resume Workshop" }
    street_address { "123 Main St" }
    city { "Baton Rouge" }
    state { "LA" }
    zip_code { "70802" }
    contact_name { "Casey Doe" }
    contact_email { "casey@example.com" }

    transient do
      date { activity_flow.reporting_window_range.end }
      hours { nil }
    end

    after(:create) do |activity, evaluator|
      next if evaluator.hours.nil?

      create(:job_training_activity_month,
        job_training_activity: activity,
        month: evaluator.date.beginning_of_month,
        hours: evaluator.hours)
    end
  end
end
