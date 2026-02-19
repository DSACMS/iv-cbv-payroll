FactoryBot.define do
  factory :volunteering_activity do
    activity_flow { association(:activity_flow,
                           volunteering_activities_count: 0,
                           job_training_activities_count: 0,
                           education_activities_count: 0) }
    organization_name { "Local Food Bank" }
    street_address { "123 Main St" }
    city { "Springfield" }
    state { "Illinois" }
    zip_code { "62701" }
    coordinator_name { "Jane Smith" }
    coordinator_email { "jane@example.com" }

    after(:build) do |activity|
      activity.date ||= activity.activity_flow.reporting_window_range.end
    end
  end
end
