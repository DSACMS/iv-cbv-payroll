require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::PinwheelReport, type: :service do
  include PinwheelApiHelper

  let(:account) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }
  let(:platform_id) { "fce3eee0-285b-496f-9b36-30e976194736" }
  let(:today) { Date.today }
  let(:days_ago_to_fetch) { 90 }
  let(:days_ago_to_fetch_for_gig) { 90 }

  let!(:payroll_account) do
    create(:payroll_account, :pinwheel_fully_synced, pinwheel_account_id: account)
  end

  let(:pinwheel_service) { Aggregators::Sdk::PinwheelService.new(:sandbox) }
  let(:report) do
    described_class.new(
      payroll_accounts: [ payroll_account ],
      pinwheel_service: pinwheel_service,
      days_to_fetch_for_w2: days_ago_to_fetch,
      days_to_fetch_for_gig: days_ago_to_fetch_for_gig
    )
  end

  let(:identities_json) { pinwheel_load_relative_json_file('request_identity_response.json') }
  let(:incomes_json) { pinwheel_load_relative_json_file('request_income_metadata_response.json') }
  let(:employments_json) { pinwheel_load_relative_json_file('request_employment_info_response.json') }
  let(:paystubs_json) { pinwheel_load_relative_json_file('request_end_user_paystubs_response.json') }
  let(:shifts_json) { pinwheel_load_relative_json_file('request_end_user_shifts_response.json') }
  let(:account_json) { pinwheel_load_relative_json_file('request_end_user_account_response.json') }
  let(:platform_json) { pinwheel_load_relative_json_file('request_platform_response.json') }

  let(:empty_pinwheel_result) { { "result" => [] } }

  before do
    allow(pinwheel_service).to receive(:fetch_identity_api).with(account_id: account).and_return(identities_json)
    allow(pinwheel_service).to receive(:fetch_income_api).with(account_id: account).and_return(incomes_json)
    allow(pinwheel_service).to receive(:fetch_employment_api).with(account_id: account).and_return(employments_json)
    allow(pinwheel_service).to receive(:fetch_paystubs_api).with(account_id: account, from_pay_date: days_ago_to_fetch.days.ago, to_pay_date: today).and_return(paystubs_json)
    allow(pinwheel_service).to receive(:fetch_shifts_api).with(account_id: account).and_return(shifts_json)
    allow(pinwheel_service).to receive(:fetch_account).with(account_id: account).and_return(account_json)
    allow(pinwheel_service).to receive(:fetch_platform).with(platform_id).and_return(platform_json)
  end

  around do |ex|
    Timecop.freeze(today, &ex)
  end

  describe '#fetch' do
    it 'calls the expected API\'s for each payroll account' do
      report.fetch
      expect(pinwheel_service).to have_received(:fetch_identity_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_account).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_paystubs_api).with(account_id: account, from_pay_date: days_ago_to_fetch.days.ago, to_pay_date: today).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_employment_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_income_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_shifts_api).with(account_id: account).exactly(1).times
      expect(pinwheel_service).to have_received(:fetch_platform).with(platform_id).exactly(1).times
    end

    it 'transforms all response objects correctly' do
      report.fetch
      expect(report.identities).to all(be_an(Aggregators::ResponseObjects::Identity))
      expect(report.employments).to all(be_an(Aggregators::ResponseObjects::Employment))
      expect(report.incomes).to all(be_an(Aggregators::ResponseObjects::Income))
      expect(report.paystubs).to all(be_an(Aggregators::ResponseObjects::Paystub))
      expect(report.gigs).to all(be_an(Aggregators::ResponseObjects::Gig))
    end

    it 'sets @has_fetched to true on success' do
      report.fetch
      expect(report.has_fetched).to be true
    end

    it 'has the correct number of response objects' do
      report.fetch
      expect(report.identities.length).to eq(1)
      expect(report.employments.length).to eq(1)
      expect(report.incomes.length).to eq(1)
      expect(report.paystubs.length).to eq(1)
      expect(report.gigs.length).to eq(3)
    end

    describe "#summarize_by_month" do
      it "returns a hash of monthly totals" do
        report.fetch
        monthly_summary_all_accounts = report.summarize_by_month(from_date: Date.parse("2020-12-05"))
        expect(monthly_summary_all_accounts.keys).to match_array([ account ])
        monthly_summary = monthly_summary_all_accounts[account]
        expect(monthly_summary.keys).to match_array([ "2020-12" ])

        dec = monthly_summary["2020-12"]
        expect(dec[:gigs].length).to eq(3)
        expect(dec[:paystubs].length).to eq(1)
        expect(dec[:accrued_gross_earnings]).to eq(480720) # in cents
        expect(dec[:total_gig_hours]).to eq(45.0)
        expect(dec[:partial_month_range]).to an_object_eq_to({
                                                               is_partial_month: true,
                                                               description: "(Partial month: from 12/5-12/31)",
                                                               included_range_start: Date.parse("2020-12-05"),
                                                               included_range_end: Date.parse("2020-12-31")
                                                             })
      end
    end

    context "in an agency configured to fetch 182 days of gig data" do
      let(:days_ago_to_fetch_for_gig) { 182 }

      it "fetches 90 days of data for a non-gig employee" do
        report.fetch
        expect(pinwheel_service).to have_received(:fetch_paystubs_api).with(
          account_id: account,
          from_pay_date: days_ago_to_fetch.days.ago,
          to_pay_date: today
        ).exactly(1).times

        expect(report.from_date).to eq(days_ago_to_fetch.days.ago)
        expect(report.to_date).to eq(Date.current)
      end

      context "for a gig employee" do
        let(:employments_json) { pinwheel_load_relative_json_file('request_employment_info_gig_worker_response.json') }

        before do
          allow(pinwheel_service).to receive(:fetch_paystubs_api).with(account_id: account, from_pay_date: days_ago_to_fetch_for_gig.days.ago, to_pay_date: today).and_return(paystubs_json)
        end

        it "fetches 182 days of data" do
          report.fetch
          expect(pinwheel_service).to have_received(:fetch_paystubs_api).with(
            account_id: account,
            from_pay_date: days_ago_to_fetch_for_gig.days.ago,
            to_pay_date: today
          ).exactly(1).times

          expect(report.from_date).to eq(days_ago_to_fetch_for_gig.days.ago)
          expect(report.to_date).to eq(Date.current)
        end
      end
    end

    describe "#summarize_by_employer" do
      it "should return an array of employer objects" do
        report.fetch
        summary = report.summarize_by_employer
        expect(summary.keys.length).to eq(1)
        expect(summary[account]).to include(
                                      has_employment_data: true,
                                      has_identity_data: true,
                                      has_income_data: true
                                    )

        expect(summary[account][:identity]).to have_attributes(
                                               account_id: account,
                                               date_of_birth: "1993-08-28",
                                               full_name: "Ash Userton",
                                               ssn: "XXX-XX-1234",
                                               emails: [ "user_good@example.com" ],
                                               phone_numbers: [ { "type"=>nil, "value"=>"+12345556789" } ]
                                             )
        expect(summary[account][:income]).to have_attributes(
                                               account_id: account,
                                               compensation_amount: 1000.0,
                                               compensation_unit: "hourly",
                                               pay_frequency: "bi-weekly"
                                             )

        expect(summary[account][:employment]).to have_attributes(
                                               account_id: account,
                                               employment_type: :w2,
                                               account_source: "Testing Payroll Provider Inc.",
                                               employer_address: "20429 Pinwheel Drive, New York City, NY 99999",
                                               employer_name: "Acme Corporation",
                                               start_date: "2010-01-01",
                                               status: "employed",
                                               termination_date: nil,
                                             )

        expect(summary[account][:paystubs][0]).to have_attributes(
                                                    account_id: account,
                                                    gross_pay_amount: 480720,
                                                    net_pay_amount: 321609,
                                                    gross_pay_ytd: 6971151,
                                                    pay_period_start: "2020-12-10",
                                                    pay_period_end: "2020-12-24",
                                                    pay_date: "2020-12-31",
                                                    hours_by_earning_category: {
                                                      "salary" => 80
                                                    },
                                                    hours: 80,
                                                    )

        expect(summary[account][:paystubs][0][:deductions][0]).to have_attributes(category: "retirement", amount: 7012)
        expect(summary[account][:paystubs][0][:deductions][1]).to have_attributes(category: "commuter", amount: 57692)
        expect(summary[account][:paystubs][0][:deductions][2]).to have_attributes(category: "empty_deduction", amount: 0)

        expect(summary[account][:paystubs][0][:earnings][0]).to have_attributes(category: "salary", amount: 380720, hours: 80, name: "Regular", rate: 4759)
        expect(summary[account][:paystubs][0][:earnings][1]).to have_attributes(category: "bonus", amount: 100000, hours: nil, name: "Bonus", rate: nil)
      end
    end

    context 'when an error occurs' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error on fetch_identity' do
        allow(pinwheel_service).to receive(:fetch_identity_api).and_raise(StandardError.new('API error'))

        report.fetch
        expect(Rails.logger).to have_received(:error).with(/Report Fetch Error: API error/)
        expect(report.has_fetched).to be false
      end

      it 'continues if an error on fetch_platform' do
        allow(pinwheel_service).to receive(:fetch_platform).and_raise(StandardError.new('API error'))

        report.fetch
        expect(Rails.logger).to have_received(:error).with(/Failed to fetch platform: API error/)
        expect(report.has_fetched).to be true
        expect(report.employments.first).to have_attributes(
                                                   account_id: account,
                                                   account_source: nil,
                                                   employment_type: :w2,
                                                   employer_address: "20429 Pinwheel Drive, New York City, NY 99999",
                                                   employer_name: "Acme Corporation",
                                                   start_date: "2010-01-01",
                                                   status: "employed",
                                                   termination_date: nil,
                                                   )
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(pinwheel_service).to receive(:fetch_identity_api).and_return(empty_pinwheel_result)
      end

      it 'sets @identities to an empty array' do
        report.fetch
        expect(report.identities).to eq([])
      end
    end

    context 'when API\'s returns empty responses' do
      before do
        allow(pinwheel_service).to receive(:fetch_identity_api).with(account_id: account).and_return(empty_pinwheel_result)
        allow(pinwheel_service).to receive(:fetch_income_api).with(account_id: account).and_return(empty_pinwheel_result)
        allow(pinwheel_service).to receive(:fetch_employment_api).with(account_id: account).and_return(empty_pinwheel_result)
        allow(pinwheel_service).to receive(:fetch_paystubs_api).with(account_id: account).and_return(empty_pinwheel_result)
      end

      it 'sets all instance variables to empty arrays' do
        report.fetch
        expect(report.identities).to eq([])
        expect(report.incomes).to eq([])
        expect(report.employments).to eq([])
        expect(report.paystubs).to eq([])
      end
    end
  end
end
