require "dry-validation"

module Aggregators::Contracts
  class MinimumReportingRequirementsSchema < Dry::Validation::Contract
    # Define the parameters structure, including nested validations
    params do
      required(:identities).filled(:array) # Allow any data type and use custom rules below.
      required(:employments).filled(:array)
      required(:paystubs).filled(:array)
      required(:is_w2).filled(:bool)
    end

    # Custom rules for `identities`
    rule(:identities).each do
      identity = value
      key.failure("full_name must be present") unless identity.full_name.present?
    end

    # Custom rules for `employments`
    rule(:employments).each do
      employment = value
      key.failure("employer_name must be present") unless employment.employer_name.present?
    end

    # Custom rules for `paystubs`
    rule(:paystubs).each do
      # Individual values from the paystub
      paystub = value
      key.failure("pay_date must be present") unless paystub.pay_date.present?
      key.failure("pay_period_start must be present") unless paystub.pay_period_start.present?
      key.failure("pay_period_end must be present") unless paystub.pay_period_end.present?
      key.failure("gross_pay_amount must be present and greater than 0") unless paystub.gross_pay_amount.present? && paystub.gross_pay_amount.to_f > 0
      key.failure("hours must be present and greater than 0") unless paystub.hours.present? && paystub.hours.to_f > 0

      if values[:is_w2]
        key.failure("earnings must have a category with hours") unless paystub.hours_by_earning_category&.any? { | category, hours| hours.to_f > 0 }
      end
    end
  end
end
