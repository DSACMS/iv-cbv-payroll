FactoryBot.define do
  factory :pinwheel_report, class: 'Aggregators::AggregatorReports::PinwheelReport' do
    identities { [
      Aggregators::ResponseObjects::Identity.new(
        account_id: "account1",
        full_name: "John Smith."
    ) ]}
    incomes { [
      Aggregators::ResponseObjects::Income.new(
        account_id: "account1",
        pay_frequency: "weekly",
        compensation_amount: 4444.44,
        compensation_unit: "USD"
      )
    ] }
    employments { [
      Aggregators::ResponseObjects::Employment.new(
        account_id: "account1",
        employer_name: "ACME Corp.",
        start_date: "2020-01-01",
        termination_date: nil,
        status: "employed"
    )
    ] }
    paystubs { [
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "account1",
        gross_pay_amount: 1111.11,
        net_pay_amount: 1000.00,
        gross_pay_ytd: 5555.55,
        pay_period_start: "2021-09-01",
        pay_period_end: "2021-09-15",
        pay_date: "2021-09-20",
        hours: 40,
        hours_by_earning_category: [
          { category: "regular", hours: 40 }
        ],
        deductions: [
          OpenStruct.new(
            category: "tax",
            amount: 111.11,
          )
      ]),
      Aggregators::ResponseObjects::Paystub.new(
        account_id: "account1",
        gross_pay_amount: 1611.11,
        net_pay_amount: 1500.00,
        gross_pay_ytd: 7266.66,
        pay_period_start: "2021-09-16",
        pay_period_end: "2021-09-30",
        pay_date: "2021-10-07",
        hours: 40,
        hours_by_earning_category: [
          { category: "regular", hours: 40 },
          { category: "overtime", hours: 10 }
        ],
        deductions: [
          OpenStruct.new(
            category: "tax",
            amount: 111.11,
          ),
          OpenStruct.new(
            category: "Empty deduction",
            amount: 0.00,
          )
      ])
    ] }
    from_date { "2021-09-01" }
    to_date { "2021-09-30" }
    pinwheel_service { "hi" }
    payroll_accounts { [] }

    trait :no_paystubs do
      paystubs { [] }
    end

    trait :with_pinwheel_account do
      payroll_accounts { [
        create(:payroll_account, :pinwheel_fully_synced, pinwheel_account_id: "account1")
      ] }
    end
  end
end
