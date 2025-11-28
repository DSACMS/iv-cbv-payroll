FactoryBot.define do
  factory :enrollment do
    semester_start do
      year = Date.today.year - Random.rand(5)
      month = [ 5, 6, 8, 9 ].sample

      Faker::Date.in_date_period(month: month, year: year)
    end

    status do
      [:full_time, :part_time, :quarter_time].sample
    end

    school { association :school, enrollment_count: 0 }

    after(:build) do |enrollment|
      enrollment.school.enrollments = [enrollment]
    end
  end
end
