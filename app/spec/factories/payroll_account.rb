FactoryBot.define do
  factory :payroll_account, class: "PayrollAccount" do
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
