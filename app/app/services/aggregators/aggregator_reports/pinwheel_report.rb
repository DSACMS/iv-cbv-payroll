module Aggregators::AggregatorReports
  class PinwheelReport < AggregatorReport
    def is_ready_to_fetch?
      @payroll_accounts.all? do |payroll_account|
        payroll_account.job_succeeded?("employment") &&
        payroll_account.job_succeeded?("income") &&
        payroll_account.job_succeeded?("identity") &&
        payroll_account.job_succeeded?("paystubs")
      end
    end

    private

    def fetch_report_data
      @payroll_accounts.each do |account|
        begin
          fetch_report_data_for_account(account)
        rescue StandardError => e
          Rails.logger.error("Report Fetch Error: #{e.message}")
          return @has_fetched = false
        end
      end
      @has_fetched = true
    end

    def fetch_report_data_for_account(account)
      begin
        @identities.append(fetch_identity(account_id: account))
        @employments.append(fetch_employment(account_id: account))
        @incomes.append(fetch_income(account_id: account))
        @paystubs.append(fetch_paystubs(account_id: account))
      end
    end

    def transform_paystubs
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/paystubs"), params).body
      json["data"].map { |paystub_json| Aggregators::ResponseObjects::Paystub.from_pinwheel(paystub_json) }
    end

    def fetch_employment(account_id:)
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/employment")).body

      Aggregators::ResponseObjects::Employment.from_pinwheel(json["data"])
    end

    def fetch_identity(account_id:)
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/identity")).body

      Aggregators::ResponseObjects::Identity.from_pinwheel(json["data"])
    end

    def fetch_income(account_id:)
      json = @http.get(build_url("#{ACCOUNTS_ENDPOINT}/#{account_id}/income")).body

      Aggregators::ResponseObjects::Income.from_pinwheel(json["data"])
    end
  end
end
