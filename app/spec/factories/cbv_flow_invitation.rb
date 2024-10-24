FactoryBot.define do
  factory :cbv_flow_invitation, class: "CbvFlowInvitation" do
    first_name { "Jane" }
    middle_name { "Sue" }
    language { :en }
    last_name { "Doe" }
    site_id { "sandbox" }
    email_address { "test@example.com" }
    snap_application_date { Time.zone.today.strftime("%m/%d/%Y") }
    user

    trait :nyc do
      site_id { "nyc" }

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
      site_id { "ma" }

      agency_id_number do
        7.times.map { rand(10) }.join
      end

      beacon_id do
        6.times.map { ('A'..'Z').to_a.sample }.join
      end
    end
  end
end
