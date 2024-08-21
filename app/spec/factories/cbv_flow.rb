FactoryBot.define do
  factory :cbv_flow do
    case_number { "ABC1234" }
    site_id { "sandbox" }

    cbv_flow_invitation

    trait :with_pinwheel_account do
      pinwheel_accounts { [ create(:pinwheel_account) ] }
    end
  end
end
