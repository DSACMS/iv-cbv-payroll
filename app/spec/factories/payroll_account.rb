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
      supported_jobs { Webhooks::Argyle.get_supported_jobs }
    end

    trait :argyle_fully_synced do
      argyle

      after(:build) do |payroll_account, evaluator|
        payroll_account.supported_jobs.each do |job|
          # Get the mapping from jobs to webhook events
          webhook_events_map = PayrollAccount::Argyle.jobs_to_webhook_events
          event_name = webhook_events_map[job]

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
