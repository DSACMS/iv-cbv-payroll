require 'faker'

FactoryBot.define do
  factory :education_activity do
    activity_flow { association(:activity_flow,
                                volunteering_activities_count: 0,
                                job_training_activities_count: 0,
                                education_activities_count: 0) }

    after(:build) do |activity|
      activity.activity_flow.education_activities = [ activity ]
    end
  end
end
