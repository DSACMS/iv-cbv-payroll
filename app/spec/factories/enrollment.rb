FactoryBot.define do
  factory :enrollment do
    semester_start do
      year = Date.today.year - Random.rand(5)
      month = [ 2, 3, 8, 9 ].sample

      Faker::Date.in_date_period(month: month, year: year)
    end

    status do
      [ :full_time, :part_time, :quarter_time ].sample
    end

    school { association :school, enrollment_count: 0 }

    after(:build) do |enrollment|
      enrollment.school.enrollments = [ enrollment ]
    end

    trait :current do
      semester_start do
        Faker::Date.between(from: Date.today.prev_month(6),
                           to: Date.today.next_month(6))
      end
    end

    trait :not_current do
      semester_start do
        Faker::Date.between(from: Date.today.prev_year,
                           to: Date.today.prev_month(7))
      end
    end
  end
end
