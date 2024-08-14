FactoryBot.define do
  factory :cbv_flow_invitation, class: "CbvFlowInvitation" do
    first_name { "Jane" }
    middle_name { "Sue" }
    last_name { "Doe" }
    case_number { "ABC1234" }
    site_id { "sandbox" }
    email_address { "test@example.com" }
    snap_application_date { Date.today.strftime("%m/%d/%Y") }
  end
end
