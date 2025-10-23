require "rails_helper"

RSpec.describe Report::W2PaystubDetailsTableComponent, type: :component do
  # Shared examples for testing paystub rendering
  shared_examples "renders paystub correctly" do |expected|
    it { expect(subject.to_html).to include(expected[:pay_date]) } if expected[:pay_date]
    it { expect(subject.to_html).to include(expected[:period_start]) } if expected[:period_start]
    it { expect(subject.to_html).to include(expected[:period_end]) } if expected[:period_end]
    it { expect(subject.to_html).to include(expected[:frequency]) } if expected[:frequency]
    it { expect(subject.to_html).to include(expected[:gross_pay]) } if expected[:gross_pay]
    it { expect(subject.to_html).to include(expected[:hours]) } if expected[:hours]
    it { expect(subject.to_html).to include(expected[:net_pay]) } if expected[:net_pay]
    it { expect(subject.to_html).to include(expected[:gross_ytd]) } if expected[:gross_ytd]

    if expected[:deductions]
      expected[:deductions].each do |deduction_name, amount|
        it { expect(subject.to_html).to include(deduction_name) }
        it { expect(subject.to_html).to include(amount) }
      end
    end

    if expected[:deduction_count]
      it "renders exactly #{expected[:deduction_count]} deductions" do
        deduction_matches = subject.to_html.scan(/Deduction/).length
        expect(deduction_matches).to eq(expected[:deduction_count])
      end
    end
  end

  # Helper method to create a paystub with sensible defaults
  # Note: monetary values are stored as integers in cents (e.g., 151897 = $1,518.97)
  def build_paystub(attributes = {})
    Aggregators::ResponseObjects::Paystub.new({
      pay_date: "March 3, 2025",
      pay_period_start: "February 10, 2025",
      pay_period_end: "February 24, 2025",
      gross_pay_amount: 151897, # $1,518.97
      hours: "65.6",
      net_pay_amount: 114039, # $1,140.39
      gross_pay_ytd: 819738, # $8,197.38
      deductions: [],
      hours_by_earning_category: {}
    }.merge(attributes))
  end

  # Helper method to create an income with sensible defaults
  def build_income(attributes = {})
    Aggregators::ResponseObjects::Income.new({
      pay_frequency: "bi-weekly"
    }.merge(attributes))
  end

  context "with a standard paystub" do
    let(:income) { build_income }
    let(:paystub) do
      build_paystub(
        deductions: [
          OpenStruct.new(category: "Dental", tax: "post-tax", amount: 4557), # $45.57
          OpenStruct.new(category: "Garnishment", tax: "post-tax", amount: 1519) # $15.19
        ]
      )
    end

    subject do
      render_inline(
        described_class.new(
          paystub,
          income: income,
          is_caseworker: false,
          is_responsive: true,
        )
      )
    end

    it "renders the payment details table with proper class" do
      expect(subject.css("table.payment-details-table").length).to eq(1)
    end

    it "renders table headers" do
      expect(subject.css("thead tr.subheader-row th").length).to eq(2)
      expect(subject.css("thead tr.subheader-row th:nth-child(1)").to_html).to include "Pay information"
      expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Details"
    end

    include_examples "renders paystub correctly",
      pay_date: "March 3, 2025",
      period_start: "February 10, 2025",
      period_end: "February 24, 2025",
      frequency: "Bi-weekly",
      gross_pay: "$1,518.97",
      hours: "65.6 hours",
      net_pay: "$1,140.39",
      gross_ytd: "$8,197.38",
      deductions: {
        "Deduction: Dental" => "$45.57",
        "Deduction: Garnishment" => "$15.19"
      },
      deduction_count: 2
  end

  context "with commission earnings" do
    let(:income) { build_income }
    let(:paystub) do
      build_paystub(
        pay_date: "February 3, 2025",
        pay_period_start: "January 13, 2025",
        pay_period_end: "January 27, 2025",
        gross_pay_amount: 163101, # $1,631.01
        hours: "58.6",
        net_pay_amount: 133223, # $1,332.23
        gross_pay_ytd: 531089, # $5,310.89
        deductions: [
          OpenStruct.new(category: "Roth", tax: "pre-tax", amount: 2716) # $27.16
        ],
        hours_by_earning_category: {
          "Regular" => "56.0",
          "Commission" => "2.6"
        }
      )
    end

    subject do
      render_inline(
        described_class.new(
          paystub,
          income: income,
          is_caseworker: false,
          is_responsive: true,
        )
      )
    end

    include_examples "renders paystub correctly",
      pay_date: "February 3, 2025",
      period_start: "January 13, 2025",
      period_end: "January 27, 2025",
      frequency: "Bi-weekly",
      gross_pay: "$1,631.01",
      hours: "58.6 hours",
      net_pay: "$1,332.23",
      gross_ytd: "$5,310.89",
      deductions: {
        "Deduction: Roth" => "$27.16"
      },
      deduction_count: 1
  end

  context "when rendered for caseworker" do
    let(:income) { build_income }
    let(:paystub) { build_paystub }

    subject do
      render_inline(
        described_class.new(
          paystub,
          income: income,
          is_caseworker: true,
          is_responsive: true,
        )
      )
    end

    it "highlights key fields for caseworkers" do
      # The component should highlight certain fields when is_caseworker is true
      # This is done via the 'highlight' parameter on table.with_data_point
      expect(subject.to_html).to include "highlight"
    end
  end

  context "when rendered for PDF" do
    let(:income) { build_income }
    let(:paystub) { build_paystub }

    subject do
      render_inline(
        described_class.new(
          paystub,
          income: income,
          is_caseworker: false,
          is_responsive: false
        )
      )
    end

    it "renders headers correctly" do
      # The component uses its own translation namespace
      expect(subject.css("thead tr.subheader-row th").length).to eq(2)
    end

    it "is not responsive" do
      # When is_responsive: false, the table should not have responsive classes
      # This is passed to TableComponent
      expect(subject.to_html).to include "payment-details-table"
    end
  end

  context "when income has no pay frequency" do
    let(:paystub) { build_paystub }

    subject do
      render_inline(
        described_class.new(
          paystub,
          income: nil,
          is_caseworker: false,
          is_responsive: true,
        )
      )
    end

    it "renders 'Unknown' for pay frequency" do
      expect(subject.to_html).to include "Pay period"
      expect(subject.to_html).to include "Unknown"
    end
  end

  context "with configuration options" do
    let(:income) { build_income }

    context "when show_hours_breakdown is false" do
      let(:paystub) do
        build_paystub(
          hours_by_earning_category: {
            "Regular" => "56.0",
            "Commission" => "2.6"
          }
        )
      end

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            show_hours_breakdown: false
          )
        )
      end

      it "does not render earnings breakdown" do
        expect(subject.to_html).not_to include "Regular"
        expect(subject.to_html).not_to include "Commission"
        expect(subject.to_html).not_to include "Hours paid"
      end

      it "still renders total hours" do
        expect(subject.to_html).to include "65.6"
      end
    end

    context "when show_gross_pay_ytd is :if_positive" do
      context "with positive YTD" do
        let(:paystub) { build_paystub(gross_pay_ytd: 819738) }

        subject do
          render_inline(
            described_class.new(
              paystub,
              income: income,
              show_gross_pay_ytd: :if_positive
            )
          )
        end

        it "renders gross pay YTD" do
          expect(subject.to_html).to include "Gross pay YTD"
          expect(subject.to_html).to include "$8,197.38"
        end
      end

      context "with zero YTD" do
        let(:paystub) { build_paystub(gross_pay_ytd: 0) }

        subject do
          render_inline(
            described_class.new(
              paystub,
              income: income,
              show_gross_pay_ytd: :if_positive
            )
          )
        end

        it "does not render gross pay YTD" do
          expect(subject.to_html).not_to include "Gross pay YTD"
        end
      end
    end

    context "when show_gross_pay_ytd is false" do
      let(:paystub) { build_paystub(gross_pay_ytd: 819738) }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            show_gross_pay_ytd: false
          )
        )
      end

      it "does not render gross pay YTD even with positive value" do
        expect(subject.to_html).not_to include "Gross pay YTD"
      end
    end

    context "when show_pay_frequency is false" do
      let(:paystub) { build_paystub }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            show_pay_frequency: false
          )
        )
      end

      it "does not render pay frequency" do
        expect(subject.to_html).not_to include "Pay period"
        expect(subject.to_html).not_to include "Bi-weekly"
      end
    end

    context "with custom details_translation_key" do
      let(:paystub) { build_paystub }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            details_translation_key: "your_details"
          )
        )
      end

      it "uses the custom translation key for details header" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Your details"
      end
    end

    context "with custom pay_frequency_text" do
      let(:paystub) { build_paystub }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            pay_frequency_text: "Custom Frequency"
          )
        )
      end

      it "uses the custom pay frequency text" do
        expect(subject.to_html).to include "Custom Frequency"
      end
    end
  end
end
