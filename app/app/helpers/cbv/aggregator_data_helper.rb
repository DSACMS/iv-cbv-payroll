module Cbv::AggregatorDataHelper
  include ReportViewHelper
  include Aggregators::AggregatorReports

  def set_aggregator_report
    if has_payroll_accounts("pinwheel") && has_payroll_accounts("argyle")
      @aggregator_report = CompositeReport.new([ make_pinwheel_report, make_argyle_report ])
    elsif has_payroll_accounts("pinwheel")
      @aggregator_report = make_pinwheel_report
    elsif has_payroll_accounts("argyle")
      @aggregator_report = make_argyle_report
    else
      raise "No reports found"
    end
  end

  def set_aggregator_report_for_account(payroll_account)
    if payroll_account.type == "pinwheel"
      @aggregator_report = make_pinwheel_report(payroll_account: payroll_account)
    elsif payroll_account.type == "argyle"
      @aggregator_report = make_argyle_report(payroll_account: payroll_account)
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

  def make_pinwheel_report(payroll_account: nil)
    report = PinwheelReport.new(
        payroll_accounts: if payroll_account.present? then [ payroll_account ] else filter_payroll_accounts("pinwheel") end,
        pinwheel_service: pinwheel,
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date)
    report.fetch
    report
  end

  def make_argyle_report(payroll_account: nil)
    report = ArgyleReport.new(
        payroll_accounts: if payroll_account.present? then [ payroll_account ] else filter_payroll_accounts("argyle") end,
        argyle_service: argyle,
        from_date: @cbv_flow.cbv_applicant.paystubs_query_begins_at,
        to_date: @cbv_flow.cbv_applicant.snap_application_date)
    report.fetch
    report
  end
end
