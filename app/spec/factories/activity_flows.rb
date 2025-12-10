require 'faker'

FactoryBot.define do
  factory :activity_flow do
    cbv_applicant { association :cbv_applicant }
    device_id { SecureRandom.uuid }

    transient do
      volunteering_activities_count { Faker::Number.within(range: 0..2).to_i }
      job_training_activities_count { Faker::Number.within(range: 0..2).to_i }
      education_activities_count { Faker::Number.within(range: 0..2).to_i }
      with_identity { Faker::Boolean.boolean }
    end

    identity do
      if with_identity
        association(:identity, activity_flows_count: 0)
      end
    end

    after(:create) do |flow, context|
      create_list(
        :volunteering_activity,
        context.volunteering_activities_count,
        activity_flow: flow
      )
      create_list(
        :job_training_activity,
        context.job_training_activities_count,
        activity_flow: flow
      )
      create_list(
        :education_activity,
        context.education_activities_count,
        activity_flow: flow
      )
    end
  end
end
