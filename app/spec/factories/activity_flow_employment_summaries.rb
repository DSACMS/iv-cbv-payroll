FactoryBot.define do
  factory :activity_flow_employment_summary do
    association :activity_flow
    payroll_account { association(:payroll_account, flow: activity_flow) }
    employer_name { "Test Employer" }
    employment_type { "w2" }
  end
end
