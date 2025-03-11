FactoryBot.define do
  factory :webhook_event do
    payroll_account

    event_name { "webhook_action_name" }
    event_outcome { "success" }
  end
end
