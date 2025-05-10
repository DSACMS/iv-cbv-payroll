require 'rails_helper'

RSpec.describe Aggregators::ResponseObjects::Gig do
  include PinwheelApiHelper
  include ArgyleApiHelper

  PinwheelFormatter = Aggregators::FormatMethods::Pinwheel
  ArgyleFormatter = Aggregators::FormatMethods::Argyle

  describe '.from_pinwheel' do
    let(:response_body) { pinwheel_load_relative_json_file('request_end_user_shifts_response.json') }
    let(:gig_data) { response_body["data"].first }

    it 'creates a Gig from a Pinwheel shift' do
      gig = described_class.from_pinwheel(gig_data)

      expect(gig).to have_attributes(
        account_id: gig_data["account_id"],
        gig_type: gig_data["type"],
        start_date: gig_data["start_date"],
        end_date: gig_data["end_date"],
        hours: PinwheelFormatter.hours(gig_data["earnings"]),
        compensation_amount: PinwheelFormatter.total_earnings_amount(gig_data["earnings"]),
        gig_status: nil
      )
    end
  end

  describe '.from_argyle' do
    let(:argyle_json) { argyle_load_relative_json_file('bob', 'request_gigs.json') }
    let(:gig_data) { argyle_json["results"].find { |g| g["duration"] } }

    it 'creates a Gig from an Argyle gig' do
      gig = described_class.from_argyle(gig_data)

      expect(gig).to have_attributes(
        account_id: gig_data["account"],
        gig_type: gig_data["type"],
        start_date: ArgyleFormatter.format_date(gig_data["start_datetime"]),
        end_date: ArgyleFormatter.format_date(gig_data["end_datetime"]),
        hours: ArgyleFormatter.seconds_to_hours(gig_data["duration"]),
        compensation_amount: ArgyleFormatter.format_currency(gig_data["income"]["pay"]),
        gig_status: gig_data["status"]
      )
    end
  end
end
