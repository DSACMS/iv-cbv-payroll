require_relative 'cbv_flow_invitation_provider'

FactoryBot.define do
  factory :cbv_flow_invitation, class: "CbvFlowInvitation" do
    first_name { "Jane" }
    middle_name { "Sue" }
    last_name { "Doe" }
    site_id { "sandbox" }
    email_address { "test@example.com" }
    snap_application_date { Time.zone.today.strftime("%m/%d/%Y") }
    user

    trait :with_provider do
      after(:build) do |invitation|
        invitation.define_singleton_method(:provider) do
          CbvFlowInvitationProvider
        end
      end
    end

    trait :nyc do
      site_id { "nyc" }
      case_number { CbvFlowInvitationProvider.generate_nyc_case_number }
      client_id_number { CbvFlowInvitationProvider.generate_nyc_client_id }
    end

    trait :ma do
      site_id { "ma" }
      agency_id_number { CbvFlowInvitationProvider.generate_ma_agency_id }
      beacon_id { CbvFlowInvitationProvider.generate_ma_beacon_id }
    end
  end
end
