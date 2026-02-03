# Instantiate and fetch the `AggregatorReports` subclass for a given CbvFlow.
class AggregatorReportFetcher
  def initialize(cbv_flow, agency_config: Rails.application.config.client_agencies)
    @cbv_flow = cbv_flow
    @agency_config = agency_config
  end

  def report
    if has_payroll_accounts("pinwheel") && has_payroll_accounts("argyle")
      Aggregators::AggregatorReports::CompositeReport.new(
        [ make_pinwheel_report, make_argyle_report ],
        days_to_fetch_for_w2: aggregator_lookback_days[:w2],
        days_to_fetch_for_gig: aggregator_lookback_days[:gig],
        reporting_date_range: reporting_date_range
      )
    elsif has_payroll_accounts("pinwheel")
      make_pinwheel_report
    elsif has_payroll_accounts("argyle")
      make_argyle_report
    else
      Rails.logger.error "no reports found for #{@cbv_flow.id}"
      nil
    end
  end

  def report_for_payroll_account(payroll_account)
    if payroll_account.type == "pinwheel"
      make_pinwheel_report(payroll_account: payroll_account)
    elsif payroll_account.type == "argyle"
      make_argyle_report(payroll_account: payroll_account)
    else
      raise "Unidentified aggregator type"
    end
  end

  private

  def has_payroll_accounts(aggregator)
    filter_payroll_accounts(aggregator).length > 0
  end

  def make_pinwheel_report(payroll_account: nil)
    report = Aggregators::AggregatorReports::PinwheelReport.new(
      payroll_accounts: if payroll_account.present? then [ payroll_account ] else filter_payroll_accounts("pinwheel") end,
      pinwheel_service: pinwheel,
      days_to_fetch_for_w2: aggregator_lookback_days[:w2],
      days_to_fetch_for_gig: aggregator_lookback_days[:gig],
      reporting_date_range: reporting_date_range
    )
    report.fetch
    report
  end

  def make_argyle_report(payroll_account: nil)
    report = Aggregators::AggregatorReports::ArgyleReport.new(
      payroll_accounts: if payroll_account.present? then [ payroll_account ] else filter_payroll_accounts("argyle") end,
      argyle_service: argyle,
      days_to_fetch_for_w2: aggregator_lookback_days[:w2],
      days_to_fetch_for_gig: aggregator_lookback_days[:gig],
      reporting_date_range: reporting_date_range
    )
    report.fetch
    report
  end

  def pinwheel
    environment = @agency_config[@cbv_flow.cbv_applicant.client_agency_id].pinwheel_environment
    Aggregators::Sdk::PinwheelService.new(environment)
  end

  def argyle
    environment = @agency_config[@cbv_flow.cbv_applicant.client_agency_id].argyle_environment
    Aggregators::Sdk::ArgyleService.new(environment)
  end

  def filter_payroll_accounts(aggregator)
    @cbv_flow.payroll_accounts.filter do |payroll_account|
      payroll_account.type == aggregator && payroll_account.sync_succeeded?
    end
  end

  # Returns the lookback days for fetching data from aggregators.
  # For Activity flows, uses a fixed 6-month lookback.
  # For CBV flows, uses the agency configuration.
  def aggregator_lookback_days
    @cbv_flow.aggregator_lookback_days || @agency_config[@cbv_flow.cbv_applicant.client_agency_id].pay_income_days
  end

  # Returns the date range for filtering displayed data.
  # For Activity flows, uses the reporting_window_range (1-6 months based on type).
  # For CBV flows, returns nil (no filtering - show all fetched data).
  def reporting_date_range
    @cbv_flow.respond_to?(:reporting_window_range) ? @cbv_flow.reporting_window_range : nil
  end
end
