module Cbv::AggregatorDataHelper
  include ViewHelper
  include Aggregators::AggregatorReports

  def set_aggregator_report
    @aggregator_report = PinwheelReport.new(
      payroll_accounts: @cbv_flow.payroll_accounts.filter { |payroll_account| payroll_account.type == "pinwheel" },
      pinwheel_service: pinwheel,
      from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
      to_date: @cbv_flow.cbv_applicant.snap_application_date)

    @aggregator_report.fetch()
  end

  def set_aggregator_report_for_account(payroll_account)
    @aggregator_report = PinwheelReport.new(
      payroll_accounts: [ payroll_account ],
      pinwheel_service: pinwheel,
      from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
      to_date: @cbv_flow.cbv_applicant.snap_application_date)

    @aggregator_report.fetch()
  end
end
