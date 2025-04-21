module Aggregators::Validators
  # This validator checks for presence of fields that we've determined are
  # necessary for a report to be useful to eligibility workers.
  class UsefulReportValidator < ActiveModel::Validator
    def validate(report)
      report.errors.add(:identities, "No identities present") unless report.identities.present?
      report.identities.each { |i| validate_identity(report, i) }

      report.errors.add(:employments, "No employments present") unless report.employments.present?
      report.employments.each { |e| validate_employment(report, e) }

      is_w2_worker = report.employments.none? { |e| e.employment_type == :gig }
      if report.paystubs.any?
        report.paystubs.each { |p| validate_paystub(report, p, is_w2_worker) }
        gross_pay_total += report.paystubs.each { |p| p.gross_pay_amount.to_f }.sum
        report.errors.add(:paystubs, "Report has invalid gross_pay_total") unless gross_pay_total > 0
      end
    end

    private

    def validate_identity(report, identity)
      report.errors.add(:identities, "Identity has no full_name") unless identity.full_name.present?
    end

    def validate_employment(report, employment)
      report.errors.add(:employments, "Employment has no employer_name") unless employment.employer_name.present?
    end

    def validate_paystub(report, paystub, is_w2_worker)
      report.errors.add(:paystubs, "Paystub has no pay_date") unless paystub.pay_date.present?
      report.errors.add(:paystubs, "Paystub has no gross_pay_amount") unless paystub.gross_pay_amount.present?

      if is_w2_worker
        report.errors.add(:paystubs, "Paystub has no pay_period_start") unless paystub.pay_period_start.present?
        report.errors.add(:paystubs, "Paystub has no pay_period_end") unless paystub.pay_period_end.present?
        report.errors.add(:paystubs, "Paystub has no hours") unless paystub.hours.present?
        report.errors.add(:paystubs, "Paystub has invalid hours") unless paystub.hours.to_f > 0
      end
    end
  end
end
