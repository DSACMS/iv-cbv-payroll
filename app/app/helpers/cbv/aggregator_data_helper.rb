module Cbv::AggregatorDataHelper
  include ReportViewHelper

  def set_aggregator_report
    fetcher = AggregatorReportFetcher.new(@cbv_flow)
    @aggregator_report = fetcher.report
  end

  def set_aggregator_report_for_account(payroll_account)
    fetcher = AggregatorReportFetcher.new(@cbv_flow)
    @aggregator_report = fetcher.report_for_payroll_account(payroll_account)
  end
end
