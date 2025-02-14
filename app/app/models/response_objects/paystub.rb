module ResponseObjects
  Paystub = Struct.new(
    :account_id,
    :gross_pay_amount,
    :net_pay_amount,
    :gross_pay_ytd,
    :pay_period_start,
    :pay_period_end,
    :pay_date,
    :earnings,
    :deductions,

    keyword_init: true
  ) do
    def self.from_pinwheel(response_body)
      new(
        account_id: response_body["account_id"],
        gross_pay_amount: response_body["gross_pay_amount"],
        net_pay_amount: response_body["net_pay_amount"],
        gross_pay_ytd: response_body["gross_pay_ytd"],
        pay_period_start: response_body["pay_period_start"],
        pay_period_end: response_body["pay_period_end"],
        pay_date: response_body["pay_date"],
        earnings: response_body["earnings"].map do |earning|
          PaystubEarning.new(
            category: earning["category"],
            hours: earning["hours"],
          )
        end,
        deductions: response_body["deductions"].map do |deduction|
          PaystubDeduction.new(
            category: deduction["category"],
            amount: deduction["amount"],
          )
        end,
      )
    end

    alias_attribute :start, :pay_period_start
    alias_attribute :end, :pay_period_end

    def hours
      base_hours = earnings
        .filter { |e| e.category != "overtime" }
        .map { |e| e.hours }
        .compact
        .max
      return unless base_hours

      # Add overtime hours to the base hours, because they tend to be additional
      # work beyond the other entries. (As opposed to category="premium", which
      # often duplicates other earnings' hours.)
      #
      # See FFS-1773.
      overtime_hours = earnings
        .filter { |e| e.category == "overtime" }
        .sum { |e| e.hours || 0.0 }

      base_hours + overtime_hours
    end

    def hours_by_earning_category
      earnings
        .filter { |e| e.hours && e.hours > 0 }
        .group_by { |e| e.category }
        .transform_values { |earnings| earnings.sum { |e| e.hours } }
    end
  end

  PaystubEarning = Struct.new(
    :category,
    :hours,
  )

  PaystubDeduction = Struct.new(
    :category,
    :amount,
  )
end
