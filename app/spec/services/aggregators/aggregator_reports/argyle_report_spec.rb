require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::ArgyleReport, type: :service do
  include ArgyleApiHelper

  describe '#fetch' do
    let(:account) { "abc123" }
    let!(:payroll_accounts) do
      create_list(:payroll_account, 3, :pinwheel_fully_synced, pinwheel_account_id: account)
    end
    let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
    let(:service) { described_class.new(payroll_accounts: payroll_accounts, argyle_service: argyle_service) }

    let(:identities_json) { load_relative_json_file('bob', 'request_identity.json') }
    let(:paystubs_json) { load_relative_json_file('bob', 'request_paystubs.json') }
    let(:empty_argyle_result) { { "result" => [] } }

    before do
      allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
      allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    end


    it 'calls the identities API' do
      service.fetch
      expect(argyle_service).to have_received(:fetch_identities_api)
    end

    it 'calls the paystubs API' do
      service.fetch
      expect(argyle_service).to have_received(:fetch_paystubs_api)
    end

    it 'transforms all response objects correctly' do
      service.fetch
      expect(service.instance_variable_get(:@identities)).to all(be_an(Aggregators::ResponseObjects::Identity))
      expect(service.instance_variable_get(:@employments)).to all(be_an(Aggregators::ResponseObjects::Employment))
      expect(service.instance_variable_get(:@incomes)).to all(be_an(Aggregators::ResponseObjects::Income))
      expect(service.instance_variable_get(:@paystubs)).to all(be_an(Aggregators::ResponseObjects::Paystub))
    end

    it 'sets @has_fetched to true on success' do
      service.fetch
      expect(service.instance_variable_get(:@has_fetched)).to be true
    end

    context 'when an error occurs' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_raise(StandardError.new('API error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error' do
        service.fetch
        expect(Rails.logger).to have_received(:error).with(/Report Fetch Error: API error/)
      end

      it 'sets @has_fetched to false' do
        service.fetch
        expect(service.instance_variable_get(:@has_fetched)).to be false
      end
    end

    context 'when identities API returns empty response' do
      before do
        allow(argyle_service).to receive(:fetch_identities_api).and_return(empty_argyle_result)
      end

      it 'sets @identities to an empty array' do
        service.fetch
        expect(service.instance_variable_get(:@identities)).to eq([])
      end
    end

    context 'when API\'s returns empty responses' do
      before do
        allow(argyle_service).to receive(:fetch_paystubs_api).and_return(empty_argyle_result)
        allow(argyle_service).to receive(:fetch_identities_api).and_return(empty_argyle_result)
      end

      it 'sets all instance variables to empty arrays' do
        service.fetch
        expect(service.instance_variable_get(:@identities)).to eq([])
        expect(service.instance_variable_get(:@incomes)).to eq([])
        expect(service.instance_variable_get(:@employments)).to eq([])
        expect(service.instance_variable_get(:@paystubs)).to eq([])
      end
    end
  end
  context "for Bob, an Uber driver" do
    let(:account) { "019571bc-2f60-3955-d972-dbadfe0913a8" }
    let!(:payroll_accounts) do
      create_list(:payroll_account, 1, :pinwheel_fully_synced, pinwheel_account_id: account)
    end
    let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
    let(:service) { described_class.new(payroll_accounts: payroll_accounts, argyle_service: argyle_service) }

    let(:identities_json) { load_relative_json_file('bob', 'request_identity.json') }
    let(:paystubs_json) { load_relative_json_file('bob', 'request_paystubs.json') }
    let(:empty_argyle_result) { { "result" => [] } }

    before do
      allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
      allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    end

    context "identities" do
      it 'returns an array of aggregators::responseobjects:identity' do
        service.fetch
        expect(service.identities.length).to eq(1)

        expect(service.identities).to all(be_a(Aggregators::ResponseObjects::Identity))
      end

      it 'returns expected attributes' do
        service.fetch

        expect(service.identities[0]).to have_attributes(
          account_id: account,
          full_name: "Bob Jones"
        )
      end
    end

    context "incomes" do
      it 'returns an array of Aggregators::ResponseObjects::Income' do
        service.fetch
        expect(service.incomes.length).to eq(1)

        expect(service.incomes).to all(be_a(Aggregators::ResponseObjects::Income))
      end

      it 'returns an array of Aggregators::ResponseObjects::Income' do
        service.fetch

        expect(service.incomes[0]).to have_attributes(
          account_id: account,
          pay_frequency: nil,
          compensation_amount: nil,
          compensation_unit: nil,
        )
      end
    end

    context "employments" do
      it 'returns an array of Aggregators::ResponseObjects::Employment' do
        service.fetch
        expect(service.employments.length).to eq(1)

        expect(service.employments).to all(be_a(Aggregators::ResponseObjects::Employment))
      end

      it 'returns an array of Aggregators::ResponseObjects::Employment' do
        service.fetch

        expect(service.employments[0]).to have_attributes(
          account_id: account,
          employer_name: "Lyft Driver",
          start_date: "2022-04-07",
          status: "employed",
        )
      end
    end

    context "paystubs" do
      it 'returns an array of Aggregators::ResponseObjects::Paystub' do
        service.fetch
        expect(service.paystubs.length).to eq(10)
        expect(service.paystubs).to all(be_a(Aggregators::ResponseObjects::Paystub))
      end
    end
  end


  context "for Joe, a W2 employee" do
    let(:account) { "01956d62-18a0-090f-bc09-2ac44b7edf99" }
    let(:params) { { some_param: 'value' } }
    let!(:payroll_accounts) do
      create_list(:payroll_account, 1, :pinwheel_fully_synced, pinwheel_account_id: account)
    end
    let(:argyle_service) { Aggregators::Sdk::ArgyleService.new(:sandbox) }
    let(:service) { described_class.new(payroll_accounts: payroll_accounts, argyle_service: argyle_service) }

    let(:identities_json) { load_relative_json_file('joe', 'request_identity.json') }
    let(:paystubs_json) { load_relative_json_file('joe', 'request_paystubs.json') }
    let(:empty_argyle_result) { { "result" => [] } }

    before do
      allow(argyle_service).to receive(:fetch_identities_api).and_return(identities_json)
      allow(argyle_service).to receive(:fetch_paystubs_api).and_return(paystubs_json)
    end

    context "incomes" do
      it 'returns an array of Aggregators::ResponseObjects::Income' do
        service.fetch
        expect(service.incomes.length).to eq(1)

        expect(service.incomes).to all(be_a(Aggregators::ResponseObjects::Income))
      end

      it 'returns income object with expected attributes' do
        service.fetch

        expect(service.incomes[0]).to have_attributes(
          account_id: account,
          pay_frequency: "annual",
          compensation_amount: 65904.75,
          compensation_unit: "USD"
        )
      end
    end

    context "employments" do
      it 'returns an array of Aggregators::ResponseObjects::Income' do
        service.fetch
        expect(service.employments.length).to eq(1)

        expect(service.employments).to all(be_a(Aggregators::ResponseObjects::Employment))
      end

      it 'returns income object with expected attributes' do
        service.fetch

        expect(service.employments[0]).to have_attributes(
          account_id: account,
          employer_name: "Conagra Brands",
          start_date: "2022-06-06",
          status: "employed",
        )
      end
    end
    context "paystubs" do
    it 'returns an array of Aggregators::ResponseObjects::Paystub' do
      service.fetch()
      expect(service.paystubs.length).to eq(10)
      expect(service.paystubs).to all(be_a(Aggregators::ResponseObjects::Paystub))
    end

    it 'returns with expected attributes including 1 earning category and multiple deductions' do
      service.fetch

      expect(service.paystubs[0]).to have_attributes(
        account_id: account,
        gross_pay_amount: 5492.06,
        net_pay_amount: 3350.16,
        gross_pay_ytd: 16476.18,
        pay_date: "2025-03-03",
        hours_by_earning_category: {
          "base" => 92.9177
        },
        deductions: match_array([
          have_attributes(category: "401K", amount: 109.84),
          have_attributes(category: "Vision", amount: 219.68),
          have_attributes(category: "Dental", amount: 219.68)
        ])
      )
      expect(service.paystubs[1]).to have_attributes(
        account_id: account,
        gross_pay_amount: 5492.06,
        net_pay_amount: 3899.37,
        gross_pay_ytd: 10984.12,
        pay_date: "2025-02-03",
        hours_by_earning_category: {
          "base" => 174.4026
        },
        deductions: match_array([
          have_attributes(category: "Dental", amount: 164.76),
          have_attributes(category: "Roth", amount: 164.76),
          have_attributes(category: "Garnishment", amount: 164.76)
        ])
      )
    end

    it 'ignores earning categories that do not have hours (e.g. Bonus / Commission)' do
      service.fetch

      expect(service.paystubs[3]).to have_attributes(
        account_id: account,
        gross_pay_amount: 5492.06,
        net_pay_amount: 4944.43,
        gross_pay_ytd: 74135.63,
        pay_date: "2024-12-02",
        hours_by_earning_category: {
          "base" => 139.5035
        },
        deductions: match_array([
          have_attributes(category: "Dental", amount: 164.76)
        ])
      )
    end

    it 'ignores earning categories that do not have hours (e.g. Bonus / Commission)' do
      service.fetch

      expect(service.paystubs[4]).to have_attributes(
        account_id: account,
        gross_pay_amount: 9735.94,
        net_pay_amount: 9076.89,
        gross_pay_ytd: 68643.57,
        pay_date: "2024-11-01",
        hours_by_earning_category: {
          "base" => 76.0765,
          "overtime" => 39.191
        },
        deductions: match_array([
          have_attributes(category: "Garnishment", amount: 54.92)
        ])
      )
    end
  end
  end
end
