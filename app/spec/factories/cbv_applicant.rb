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
    end
  end
end
