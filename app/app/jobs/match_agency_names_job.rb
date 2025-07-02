class MatchAgencyNamesJob < ApplicationJob
  include Cbv::AggregatorDataHelper

  def perform(cbv_flow_id)
    @cbv_flow = CbvFlow.find(cbv_flow_id)

    agency_expected_names = @cbv_flow.cbv_applicant.agency_expected_names
    unless agency_expected_names.any?
      Rails.logger.info "No agency-expected names to match to report names."
      return
    end

    # Fetch the report(s)
    set_aggregator_report

    report_names = @aggregator_report.identities.map do |identity|
      "#{identity["first_name"]} #{identity["last_name"]}"
    end

    name_match_results =
      if agency_expected_names.any?
        AgencyNameMatchingService
          .new(report_names, agency_expected_names)
          .match_results
      else
        {}
      end

    event_logger.track("IncomeSummaryMatchedAgencyNames", nil, {
      timestamp: Time.now.to_i,
      client_agency_id: @cbv_flow.client_agency_id,
      cbv_applicant_id: @cbv_flow.cbv_applicant_id,
      cbv_flow_id: @cbv_flow.id,
      invitation_id: @cbv_flow.cbv_flow_invitation_id,
      total_report_names_count: report_names.length,
      total_agency_names_count: agency_expected_names.length,
      **name_match_results
    })
  end

  private

  # Necessary for methods within Cbv::AggregatorDataHelper
  def agency_config
    Rails.application.config.client_agencies
  end

  def argyle
    environment = agency_config[@cbv_flow.client_agency_id].argyle_environment
    Aggregators::Sdk::ArgyleService.new(environment)
  end

  def pinwheel
    environment = agency_config[@cbv_flow.client_agency_id].pinwheel_environment
    Aggregators::Sdk::PinwheelService.new(environment)
  end
end
