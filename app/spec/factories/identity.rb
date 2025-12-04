require 'faker'

FactoryBot.define do
  factory :identity do
    transient do
      school_count { 1 }
    end

    transient do
      activity_flow_count { 1 }
    end

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 65) }

    schools do
      Array.new(school_count) { association(:school) }
    end

    activity_flows do
      Array.new(activity_flow_count) { association(:activity_flow) }
    end
  end
end
