FactoryBot.define do
  factory :cbv_flow do
    cbv_flow_invitation
    cbv_applicant

    client_agency_id { "sandbox" }

    trait :completed do
      consented_to_authorized_use_at { 10.minutes.ago }
      confirmation_code { "SANDBOX0010002" }
    end

    trait :with_pinwheel_account do
      transient do
        supported_jobs { %w[income paystubs employment identity] }
        employment_errored_at { nil }
      end

      after(:build) do |cbv_flow, evaluator|
        cbv_flow.payroll_accounts = [
          create(:payroll_account, cbv_flow: cbv_flow, supported_jobs: evaluator.supported_jobs, employment_errored_at: evaluator.employment_errored_at)
        ]
      end
    end

    transient do
      cbv_applicant_attributes { {} }
    end
    after(:build) do |cbv_flow, evaluator|
      cbv_flow.cbv_applicant.update(evaluator.cbv_applicant_attributes)

      if cbv_flow.cbv_applicant && cbv_flow.cbv_flow_invitation
        cbv_flow.cbv_flow_invitation.update(cbv_applicant: cbv_flow.cbv_applicant)
      end
    end
  end
end
