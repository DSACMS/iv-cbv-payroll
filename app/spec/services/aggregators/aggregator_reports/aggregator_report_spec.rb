require 'rails_helper'

RSpec.describe Aggregators::AggregatorReports::AggregatorReport, type: :service do
  describe '#total_gross_income' do
    it 'handles nil gross_pay_amount values' do
      report = Aggregators::AggregatorReports::AggregatorReport.new
      report.paystubs = [
        Aggregators::ResponseObjects::Paystub.new(gross_pay_amount: 100),
        Aggregators::ResponseObjects::Paystub.new(gross_pay_amount: nil)
      ]

      expect { report.total_gross_income }.not_to raise_error
      expect(report.total_gross_income).to eq(100)
    end
  end
end
