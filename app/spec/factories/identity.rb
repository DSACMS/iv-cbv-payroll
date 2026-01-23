require 'faker'

FactoryBot.define do
  factory :identity do
    transient do
      school_count { 1 }
      activity_flows_count { 1 }
    end

    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 65) }

    trait :nsc_linda do
      first_name { "Linda" }
      last_name { "Cooper" }
      date_of_birth { "1999-01-01" }
    end

    trait :nsc_lynette do
      first_name { "Lynette" }
      last_name { "Oyola" }
      date_of_birth { "1988-10-24" }
    end

    trait :nsc_rick do
      first_name { "Rick" }
      last_name { "Banas" }
      date_of_birth { "1979-08-18" }
    end
  end
end
