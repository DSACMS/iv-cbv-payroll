FactoryBot.define do
  factory :cbv_flow do
    case_number { "ABC1234" }
    site_id { "sandbox" }

    cbv_flow_invitation

    trait :with_pinwheel_account do
      transient do
        supported_jobs { %w[income paystubs employment] }
        employment_errored_at { nil }
      end

      after(:build) do |cbv_flow, evaluator|
        cbv_flow.pinwheel_accounts = [ create(:pinwheel_account, supported_jobs: evaluator.supported_jobs, employment_errored_at: evaluator.employment_errored_at) ]
      end
    end
  end
end
