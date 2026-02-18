FactoryBot.define do
  factory :activity_flow_monthly_summary do
    association :activity_flow
    payroll_account { association(:payroll_account, flow: activity_flow) }
    month { Date.current.beginning_of_month }
    total_w2_hours { 0.0 }
    total_gig_hours { 0.0 }
    accrued_gross_earnings_cents { 0 }
    total_mileage { 0.0 }
    paychecks_count { 0 }
    employer_name { "Test Employer" }
    employment_type { "w2" }
  end
end
