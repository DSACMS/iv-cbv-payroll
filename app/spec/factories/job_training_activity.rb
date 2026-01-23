FactoryBot.define do
  factory :job_training_activity do
    activity_flow { association(:activity_flow,
                                volunteering_activities_count: 0,
                                job_training_activities_count: 0,
                                education_activities_count: 0) }

    after(:build) do |activity|
      activity.date ||= activity.activity_flow.reporting_window_range.end
    end
  end
end
