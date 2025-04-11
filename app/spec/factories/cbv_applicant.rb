FactoryBot.define do
  factory :cbv_applicant do
    client_agency_id { "sandbox" }
    first_name { "Jane" }
    middle_name { "Sue" }
    last_name { "Doe" }
    created_at { Date.current.strftime("%m/%d/%Y") }
    snap_application_date { Date.current.strftime("%m/%d/%Y") }

    trait :nyc do
      client_agency_id { "nyc" }

      case_number do
        number = 11.times.map { rand(10) }.join
        letter = ('A'..'Z').to_a.sample
        "#{number}#{letter}"
      end

      client_id_number do
        letters = 2.times.map { ('A'..'Z').to_a.sample }.join
        numbers = 5.times.map { rand(10) }.join
        last_letter = ('A'..'Z').to_a.sample
        "#{letters}#{numbers}#{last_letter}"
      end
    end

    trait :ma do
      client_agency_id { "ma" }

      agency_id_number do
        7.times.map { rand(10) }.join
      end

      beacon_id do
        6.times.map { ('A'..'Z').to_a.sample }.join
      end
    end

    trait :az_des do
      client_agency_id { "az_des" }
      first_name { nil }
      middle_name { nil }
      last_name { nil }

      case_number do
        # TODO: Determine actual AZ DES case number format.
        8.times.map { rand(10) }.join
      end

      income_changes do
        [
          {
            change_index: 1,
            change_type: "Start",
            member_name: "Mark Scout",
            employer_name: "Walmart",
            effective_date: "2025-03-01",
            date_of_first_check: "2025-03-15",
            gross_amount_of_first_check: "600.00",
            gross_amount_per_check: "600.00",
            hourly_rate: "18.00",
            frequency: "Every Two Weeks",
            hours_per_week: "35",
            overtime: false,
            bonus: false,
            change_will_continue: false
          },
          {
            change_index: 2,
            change_type: "Stop",
            member_name: "Mark Scout",
            employer_name: "Target",
            effective_date: "2025-02-20"
          }
        ]
      end
    end
  end
end
