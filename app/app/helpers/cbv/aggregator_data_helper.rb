module Cbv::AggregatorDataHelper
  include ViewHelper
  include Aggregators::AggregatorReports

  def set_aggregator_report
    if has_payroll_accounts("pinwheel") and has_payroll_accounts("argyle")
      @aggregator_report = CompositeReport([ makePinwheelReport, makeArgyleReport ])
    elsif has_payroll_accounts("pinwheel")
      @aggregator_report = makePinwheelReport
    elsif has_payroll_accounts("argyle")
      @aggregator_report = makeArgyleReport
    else
      raise "No reports found"
    end
  end

  def set_aggregator_report_for_account(payroll_account)
    if payroll_account.type == "pinwheel"
      @aggregator_report = makePinwheelReport(payroll_account: payroll_account)
    elsif payroll_account.type == "argyle"
      @aggregator_report = makeArgyleReport(payroll_account: payroll_account)
    else
      raise "Unidentified aggregator type"
    end
  end

  def filter_payroll_accounts(aggregator)
    @cbv_flow.payroll_accounts.filter { |payroll_account| payroll_account.type == aggregator }
  end

  def has_payroll_accounts(aggregator)
    filter_payroll_accounts(aggregator).length > 0
  end

  def makePinwheelReport(payroll_account: nil)
    report = PinwheelReport.new(
        payroll_accounts: if payroll_account.present? then [ payroll_account ] else filter_payroll_accounts("pinwheel") end,
        pinwheel_service: pinwheel,
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date)
    report.fetch
    report
  end

  def makeArgyleReport(payroll_account: nil)
    report = ArgyleReport.new(
        payroll_accounts: if payroll_account.present? then [ payroll_account ] else filter_payroll_accounts("argyle") end,
        argyle_service: argyle,
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date)
    report.fetch
    report
  end
end
