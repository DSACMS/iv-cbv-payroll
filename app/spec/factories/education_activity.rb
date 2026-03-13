require 'faker'

FactoryBot.define do
  factory :education_activity do
    activity_flow { association(:activity_flow,
                                volunteering_activities_count: 0,
                                job_training_activities_count: 0,
                                education_activities_count: 0) }

    status { "unknown" }

    credit_hours { Faker::Number.within(range: 0..6).to_i }
    additional_comments { Faker::Lorem.paragraph }

    after(:build) do |activity|
      activity.activity_flow.education_activities = [ activity ]
    end

    trait :partially_self_attested do
      data_source { "partially_self_attested" }
      status { "succeeded" }
      after(:create) do |activity|
        create(:nsc_enrollment_term, :less_than_half_time, education_activity: activity)
      end
    end

    trait :validated_with_enrollment do
      status { "succeeded" }
      after(:create) do |activity|
        create(:nsc_enrollment_term, education_activity: activity)
      end
    end
  end
end
