FactoryBot.define do
  factory :pinwheel_account, class: "PinwheelAccount" do
    cbv_flow_id { "123456" }
    pinwheel_account_id { SecureRandom.uuid }
    paystubs_synced_at { DateTime.now }
    employment_synced_at { DateTime.now }
    income_synced_at { DateTime.now }
  end
end
