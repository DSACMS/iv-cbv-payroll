module TestHelpers
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  def stub_payments
    5.times.map do |i|
      {
        employer: "Employer #{i + 1}",
        net_pay_amount: (100 * (i + 1)),
        start: Date.today.beginning_of_month + i.months,
        end: Date.today.end_of_month + i.months,
        hours: (40 * (i + 1)),
        rate: (10 + i)
      }
    end
  end
end
