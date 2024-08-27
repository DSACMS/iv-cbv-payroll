FactoryBot.define do
  factory :cbv_flow do
    case_number { "ABC1234" }
    site_id { "sandbox" }

    cbv_flow_invitation

    trait :transmitted do
      transmitted_at { 10.minutes.ago }
      confirmation_code { "SANDBOX0010002" }
    end

    trait :with_pinwheel_account do
      transient do
        supported_jobs { %w[income paystubs employment identity] }
        employment_errored_at { nil }
      end

      after(:build) do |cbv_flow, evaluator|
        cbv_flow.pinwheel_accounts = [
          create(:pinwheel_account, cbv_flow: cbv_flow, supported_jobs: evaluator.supported_jobs, employment_errored_at: evaluator.employment_errored_at)
        ]
      end
    end
  end
end
