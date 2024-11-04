FactoryBot.define do
  factory :pinwheel_account, class: "PinwheelAccount" do
    cbv_flow
    pinwheel_account_id { SecureRandom.uuid }
    paystubs_synced_at { DateTime.now }
    employment_synced_at { DateTime.now }
    income_synced_at { DateTime.now }
    identity_synced_at { DateTime.now }
    supported_jobs { %w[income paystubs employment identity] }

    trait :with_paystubs_errored do
      paystubs_errored_at { DateTime.now }
    end
  end
end
