FactoryBot.define do
  factory :payroll_account, class: "PayrollAccount" do
    cbv_flow
    pinwheel_account_id { SecureRandom.uuid }
    supported_jobs { %w[income paystubs employment identity] }

    transient do
      # Use this to create a test case where a job has failed to sync for a
      # PayrollAccount.
      with_errored_jobs { %w[] }
    end

    trait :pinwheel_fully_synced do
      type { "pinwheel" }

      after(:build) do |payroll_account, evaluator|
        payroll_account.supported_jobs.each do |job|
          event_name = PayrollAccount::Pinwheel::JOBS_TO_WEBHOOK_EVENTS[job]

          payroll_account.webhook_events << build(
            :webhook_event,
            event_name: event_name,
            event_outcome: evaluator.with_errored_jobs.include?(job) ? "error" : "success"
          )
        end
      end
    end
  end
end
