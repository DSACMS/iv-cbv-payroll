class BackfillAdditionalInformationService
  class << self
    def perform(logger: Rails.logger)
      backfill_flow_class(CbvFlow, logger: logger)
      backfill_flow_class(ActivityFlow, logger: logger)
    end

    private

    def backfill_flow_class(klass, logger:)
      logger.info "Starting backfill of additional_information"

      klass.includes(:payroll_accounts).find_each do |flow|
        next if flow.additional_information.blank?

        flow.additional_information.each do |aggregator_id, data|
          payroll_account = flow.payroll_accounts.find { |pa| pa.aggregator_account_id == aggregator_id }
          unless payroll_account
            logger.info "Missing payroll account #{aggregator_id}"
            next
          end

          comment = data["comment"]
          payroll_account.update_column(:additional_information, comment)
        end
      end
    end
  end
end
