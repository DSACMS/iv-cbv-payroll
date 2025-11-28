require 'faker'

FactoryBot.define do
  factory :school do
    transient do
      enrollment_count { 1 }
    end

    name { Faker::University.name }
    address { Faker::Address.full_address }
    identity { association :identity, school_count: 0 }

    enrollments do
      Array.new(enrollment_count) { association(:enrollment) }
    end

    after(:build) do |school|
      school.identity.schools = [school]
    end
  end
end
