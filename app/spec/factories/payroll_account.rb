FactoryBot.define do
  factory :payroll_account, class: "PayrollAccount" do
    cbv_flow
    pinwheel_account_id { SecureRandom.uuid }
    supported_jobs { %w[income paystubs employment identity] }
    type { "pinwheel" }

    # Factory bot needs this to instantiate the proper subclass
    # @see https://stackoverflow.com/questions/57504422/how-to-make-factorybot-return-the-right-sti-sub-class
    initialize_with { PayrollAccount.sti_class_for(type).new }

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

    # Add new trait for Argyle PayrollAccounts
    trait :argyle do
      type { "argyle" }
      supported_jobs { Aggregators::Webhooks::Argyle.get_supported_jobs }
    end

    trait :argyle_bob do
      argyle_fully_synced

      pinwheel_account_id { "019571bc-2f60-3955-d972-dbadfe0913a8" }
    end

    trait :argyle_fully_synced do
      argyle

      after(:build) do |payroll_account, evaluator|
        payroll_account.supported_jobs.each do |job|
          payroll_account.webhook_events << build(
            :webhook_event,
            event_name: PayrollAccount::Argyle.event_for_job(job),
            event_outcome: evaluator.with_errored_jobs.include?(job) ? "error" : "success"
          )
        end
      end
    end
  end
end
