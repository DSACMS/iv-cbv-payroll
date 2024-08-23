FactoryBot.define do
  factory :cbv_flow_invitation, class: "CbvFlowInvitation" do
    first_name { "Jane" }
    middle_name { "Sue" }
    last_name { "Doe" }
    site_id { "sandbox" }
    email_address { "test@example.com" }
    snap_application_date { Date.today.strftime("%m/%d/%Y") }
    user

    trait :nyc do
      site_id { "nyc" }
      case_number { "ABC1234" }
      client_id_number { "001111111" }
    end

    trait :ma do
      site_id { "ma" }
      agency_id_number { "0001112222" }
      beacon_id { "123456" }
    end
  end
end
