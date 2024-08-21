module TestHelpers
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  def stub_payments(account_id = SecureRandom.uuid)
    5.times.map do |i|
      {
        account_id: account_id,
        employer: "Employer #{i + 1}",
        net_pay_amount: (100 * (i + 1)),
        gross_pay_amount: (120 * (i + 1)),
        start: Date.today.beginning_of_month + i.months,
        end: Date.today.end_of_month + i.months,
        hours: (40 * (i + 1)),
        rate: (10 + i),
        deductions: []
      }
    end
  end

  def stub_employments(account_id = SecureRandom.uuid)
    5.times.map do |i|
      {
        "account_id" => account_id,
        "status" => "employed",
        "start_date" => "2010-01-01",
        "termination_date" => nil,
        "employer_name" => "Acme Corporation",
        "employer_address" => {
          "raw" => "20429 Pinwheel Drive, New York City, NY 99999"
        },
        "employer_phone_number" => {
          "value" => "+16126597057"
        },
        "title" => nil
      }
    end
  end

  def stub_incomes(account_id = SecureRandom.uuid)
    5.times.map do |i|
      { 
        "account_id" => account_id,
        "id" => "c70bde4d-e1c2-427a-adc1-c17f61eff210",
        "created_at" => "2024-08-19T19:27:03.220201+00:00",
        "updated_at" => "2024-08-19T19:27:03.220201+00:00",
        "compensation_amount" => 1000,
        "compensation_unit" => "hourly",
        "currency" => "USD",
        "pay_frequency" => "bi-weekly"
      }
    end
  end
end
