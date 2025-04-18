require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::CompositeReport, type: :service do
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:argyle_report) { build(:argyle_report, :with_argyle_account) }

  describe '#init' do
    subject { Aggregators::AggregatorReports::CompositeReport.new([ pinwheel_report, argyle_report ]) }

    it 'merges identities from both reports' do
      expect(subject.identities.length).to be(2)
      expect(subject.identities).to all(be_a(Aggregators::ResponseObjects::Identity))
      expect(subject.identities.map(&:account_id)).to contain_exactly('account1', 'argyle_report1')
    end

    it 'merges incomes from both reports' do
      expect(subject.incomes.length).to be(2)
      expect(subject.incomes).to all(be_a(Aggregators::ResponseObjects::Income))
      expect(subject.incomes.map(&:account_id)).to contain_exactly('account1', 'argyle_report1')
    end

    it 'merges employments from both reports' do
      expect(subject.employments.length).to be(2)
      expect(subject.employments).to all(be_a(Aggregators::ResponseObjects::Employment))
      expect(subject.employments.map(&:account_id)).to contain_exactly('account1', 'argyle_report1')
      expect(subject.employments.map(&:employer_name)).to contain_exactly('ACME Corp.', 'Argyle Test Corp.')
    end

    it 'merges paystubs from both reports' do
      expect(subject.paystubs.length).to be(4)
      expect(subject.paystubs).to all(be_a(Aggregators::ResponseObjects::Paystub))
      expect(subject.paystubs.filter { |d| d.account_id == "account1" }.length).to be(2)
      expect(subject.paystubs.filter { |d| d.account_id == "argyle_report1" }.length).to be(2)
    end

    it 'sets the earliest from_date' do
      expect(subject.from_date).to eq(Date.parse("2021-08-01"))
    end

    it 'sets the latest to_date' do
      expect(subject.to_date).to eq(Date.parse("2021-10-30"))
    end

    it 'sets has_fetched to true' do
      expect(subject.has_fetched).to be true
    end

    it 'returns correct summarize_by_employer' do
      expect(subject.summarize_by_employer["argyle_report1"][:total]).to eq(1000.00)
      expect(subject.summarize_by_employer["argyle_report1"][:has_employment_data]).to be(true)
      expect(subject.summarize_by_employer["argyle_report1"][:has_income_data]).to be(true)
      expect(subject.summarize_by_employer["argyle_report1"][:has_identity_data]).to be(true)
      expect(subject.summarize_by_employer["account1"][:total]).to eq(2722.22)
      expect(subject.summarize_by_employer["account1"][:has_employment_data]).to be(true)
      expect(subject.summarize_by_employer["account1"][:has_income_data]).to be(true)
      expect(subject.summarize_by_employer["account1"][:has_identity_data]).to be(true)
    end
  end
end
