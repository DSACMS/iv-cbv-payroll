FactoryBot.define do
  factory :cbv_flow do
    trait :invited do
      cbv_flow_invitation
    end

    cbv_applicant

    client_agency_id { "sandbox" }

    trait :completed do
      consented_to_authorized_use_at { 10.minutes.ago }
      confirmation_code { "SANDBOX0010002" }
    end

    trait :with_pinwheel_account do
      transient do
        supported_jobs { %w[income paystubs employment identity] }
        with_errored_jobs { [] }
      end

      after(:build) do |cbv_flow, evaluator|
        cbv_flow.payroll_accounts = [
          create(:payroll_account,
            :pinwheel_fully_synced,
            with_errored_jobs: evaluator.with_errored_jobs,
            cbv_flow: cbv_flow,
            supported_jobs: evaluator.supported_jobs,
          )
        ]
      end
    end

    trait :with_argyle_account do
      transient do
        supported_jobs { Aggregators::Webhooks::Argyle.get_supported_jobs }
        with_errored_jobs { [] }
        partially_synced { false }
      end

      after(:build) do |cbv_flow, evaluator|
        sync_status = evaluator.partially_synced ? :argyle_partially_synced : :argyle_fully_synced
        cbv_flow.payroll_accounts = [
          create(:payroll_account,
                 sync_status,
                 with_errored_jobs: evaluator.with_errored_jobs,
                 cbv_flow: cbv_flow,
                 supported_jobs: evaluator.supported_jobs,
                 )
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
