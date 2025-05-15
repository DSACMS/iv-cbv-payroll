module Aggregators::Validators
  # This validator checks for presence of fields that we've determined are
  # necessary for a report to be useful to eligibility workers.
  class UsefulReportValidator < ActiveModel::Validator
    def validate(report)
      report.errors.add(:identities, "No identities present") unless report.identities.present?
      report.identities.each { |i| validate_identity(report, i) }

      report.errors.add(:employments, "No employments present") unless report.employments.present?
      report.employments.each { |e| validate_employment(report, e) }
      # If not actively employed we don't want to run paystub level validations.
      # Its important that we share any confirmation of loss of employment with the state agency
      unless is_unemployed(report)
        is_w2_worker = report.employments.none? { |e| e.employment_type == :gig }
        if report.paystubs.any?
          validate_paystubs(report, is_w2_worker)
        end
      end
    end

    private

    # We're working with incomplete and bad data. There are a few ways to determine if an account is no longer actively employed
    # Not actively employed means status is not 'employed' OR
    # termination_date is not empty OR
    # The acccount has empty employment status, no termination date, no gross pay and no hours
    def is_unemployed(report)
      report.employments.each do |employment|
        employment_paystubs = paystubs_for_account(report, employment.account_id)
        # TODO turn employment status into a constant or a symbol
        return true if employment.status.present? && employment.status != "employed"
        return true if employment.termination_date.present?
        hours_total = employment_paystubs.filter { | p| p.hours.present? }.sum { |p| p.hours.to_f }
        gross_pay_total = employment_paystubs.sum { |paystub| paystub.gross_pay_amount.to_f }
        return true if hours_total == 0 && gross_pay_total == 0
      end
      # We know the person is employed if we hit this point
      false
    end

    def paystubs_for_account(report, account_id)
      report.paystubs.select { |paystub| paystub.account_id == account_id }
    end

    def validate_identity(report, identity)
      report.errors.add(:identities, "Identity has no full_name") unless identity.full_name.present?
    end

    def validate_employment(report, employment)
      report.errors.add(:employments, "Employment has no employer_name") unless employment.employer_name.present?
    end

    def validate_paystubs(report, is_w2_worker)
      report.errors.add(:paystubs, "No paystub has pay_date") unless report.paystubs.any? { |paystub| paystub.pay_date.present? }
      report.errors.add(:paystubs, "No paystub has gross_pay_amount") unless report.paystubs.any? { |paystub| paystub.gross_pay_amount.present? }
      report.errors.add(:paystubs, "No paystub has valid gross_pay_amount") unless report.paystubs.any? { |paystub| paystub.gross_pay_amount.to_f > 0 }

      # Removing hours check for LA launch - FFS-2866 ticket to add back logic for SNAP only pilots
      # if is_w2_worker
      #   hours_total = 0
      #   paystubs.each { |p| hours_total += p.hours.to_f if p.hours.present? }
      #   report.errors.add(:paystubs, "Report has invalid hours total") unless hours_total > 0
      # end
    end
  end
end
