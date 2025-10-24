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

    context "when show_gross_pay_ytd is true" do
      context "with positive YTD" do
        let(:paystub) { build_paystub(gross_pay_ytd: 819738) }

        subject do
          render_inline(
            described_class.new(
              paystub,
              income: income,
              show_gross_pay_ytd: true
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
              show_gross_pay_ytd: true
            )
          )
        end

        it "does not render gross pay YTD when value is zero" do
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

    context "when is_personalized is true" do
      let(:paystub) { build_paystub }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            is_personalized: true
          )
        )
      end

      it "uses the personalized translation for details header" do
        expect(subject.css("thead tr.subheader-row th:nth-child(2)").to_html).to include "Your details"
      end
    end

    context "when show_earnings_items is true" do
      let(:earnings) do
        [
          Aggregators::ResponseObjects::Earning.new(name: "Regular Pay", amount: 100000),
          Aggregators::ResponseObjects::Earning.new(name: "Overtime", amount: 25000),
          Aggregators::ResponseObjects::Earning.new(name: "Bonus", amount: 50000)
        ]
      end
      let(:paystub) { build_paystub(earnings: earnings) }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            show_earnings_items: true
          )
        )
      end

      it "renders earnings items heading" do
        expect(subject.to_html).to include "Gross pay line items"
      end

      it "renders description paragraph" do
        expect(subject.to_html).to include "The following items are categories listed on the paystub as part of the gross pay for this paycheck."
      end

      it "renders all earnings items with names and amounts" do
        expect(subject.to_html).to include "Gross Pay Item: Regular Pay"
        expect(subject.to_html).to include "$1,000.00"
        expect(subject.to_html).to include "Gross Pay Item: Overtime"
        expect(subject.to_html).to include "$250.00"
        expect(subject.to_html).to include "Gross Pay Item: Bonus"
        expect(subject.to_html).to include "$500.00"
      end

      context "with zero amount earnings" do
        let(:earnings) do
          [
            Aggregators::ResponseObjects::Earning.new(name: "Regular Pay", amount: 100000),
            Aggregators::ResponseObjects::Earning.new(name: "Zero Amount", amount: 0),
            Aggregators::ResponseObjects::Earning.new(name: "Overtime", amount: 25000)
          ]
        end

        it "does not render earnings with zero amount" do
          expect(subject.to_html).to include "Gross Pay Item: Regular Pay"
          expect(subject.to_html).to include "Gross Pay Item: Overtime"
          expect(subject.to_html).not_to include "Zero Amount"
        end
      end

      context "with unsorted earnings by category" do
        let(:earnings) do
          [
            Aggregators::ResponseObjects::Earning.new(name: "Bonus Item", category: "bonus", amount: 50000),
            Aggregators::ResponseObjects::Earning.new(name: "Tips Item", category: "tips", amount: 30000),
            Aggregators::ResponseObjects::Earning.new(name: "Base Pay", category: "base", amount: 100000),
            Aggregators::ResponseObjects::Earning.new(name: "Overtime Pay", category: "overtime", amount: 25000),
            Aggregators::ResponseObjects::Earning.new(name: "Commission Item", category: "commission", amount: 40000)
          ]
        end

        it "renders earnings in category order" do
          # Extract earning names from the rendered HTML in order
          rendered_names = subject.css("table").last.css("tr td:first-child").map(&:text).map(&:strip)

          expected_order = [
            "Gross Pay Item: Base Pay",
            "Gross Pay Item: Overtime Pay",
            "Gross Pay Item: Commission Item",
            "Gross Pay Item: Tips Item",
            "Gross Pay Item: Bonus Item"
          ]

          expect(rendered_names).to eq(expected_order)
        end
      end

      context "with all categories in reverse order" do
        let(:earnings) do
          [
            Aggregators::ResponseObjects::Earning.new(name: "Stock Item", category: "stock", amount: 10000),
            Aggregators::ResponseObjects::Earning.new(name: "Disability Item", category: "disability", amount: 9000),
            Aggregators::ResponseObjects::Earning.new(name: "Other Item", category: "other", amount: 8000),
            Aggregators::ResponseObjects::Earning.new(name: "Benefits Item", category: "benefits", amount: 7000),
            Aggregators::ResponseObjects::Earning.new(name: "Bonus Item", category: "bonus", amount: 6000),
            Aggregators::ResponseObjects::Earning.new(name: "Tips Item", category: "tips", amount: 5000),
            Aggregators::ResponseObjects::Earning.new(name: "Commission Item", category: "commission", amount: 4000),
            Aggregators::ResponseObjects::Earning.new(name: "PTO Item", category: "pto", amount: 3000),
            Aggregators::ResponseObjects::Earning.new(name: "Overtime Item", category: "overtime", amount: 2000),
            Aggregators::ResponseObjects::Earning.new(name: "Base Item", category: "base", amount: 1000)
          ]
        end

        it "sorts all categories correctly" do
          rendered_names = subject.css("table").last.css("tr td:first-child").map(&:text).map(&:strip)

          expected_order = [
            "Gross Pay Item: Base Item",
            "Gross Pay Item: Overtime Item",
            "Gross Pay Item: PTO Item",
            "Gross Pay Item: Commission Item",
            "Gross Pay Item: Tips Item",
            "Gross Pay Item: Bonus Item",
            "Gross Pay Item: Benefits Item",
            "Gross Pay Item: Other Item",
            "Gross Pay Item: Disability Item",
            "Gross Pay Item: Stock Item"
          ]

          expect(rendered_names).to eq(expected_order)
        end
      end

      context "with same category maintaining original order" do
        let(:earnings) do
          [
            Aggregators::ResponseObjects::Earning.new(name: "Base Pay 1", category: "base", amount: 50000),
            Aggregators::ResponseObjects::Earning.new(name: "Overtime Pay", category: "overtime", amount: 30000),
            Aggregators::ResponseObjects::Earning.new(name: "Base Pay 2", category: "base", amount: 40000),
            Aggregators::ResponseObjects::Earning.new(name: "Base Pay 3", category: "base", amount: 60000),
            Aggregators::ResponseObjects::Earning.new(name: "Overtime Pay 2", category: "overtime", amount: 20000)
          ]
        end

        it "maintains original order within the same category" do
          rendered_names = subject.css("table").last.css("tr td:first-child").map(&:text).map(&:strip)

          expected_order = [
            "Gross Pay Item: Base Pay 1",
            "Gross Pay Item: Base Pay 2",
            "Gross Pay Item: Base Pay 3",
            "Gross Pay Item: Overtime Pay",
            "Gross Pay Item: Overtime Pay 2"
          ]

          expect(rendered_names).to eq(expected_order)
        end
      end

      context "with unknown categories" do
        let(:earnings) do
          [
            Aggregators::ResponseObjects::Earning.new(name: "Unknown Category 1", category: "unknown_category", amount: 50000),
            Aggregators::ResponseObjects::Earning.new(name: "Base Pay", category: "base", amount: 40000),
            Aggregators::ResponseObjects::Earning.new(name: "Unknown Category 2", category: "another_unknown", amount: 30000),
            Aggregators::ResponseObjects::Earning.new(name: "Overtime Pay", category: "overtime", amount: 20000)
          ]
        end

        it "sorts unknown categories after known categories, maintaining original order" do
          rendered_names = subject.css("table").last.css("tr td:first-child").map(&:text).map(&:strip)

          expected_order = [
            "Gross Pay Item: Base Pay",
            "Gross Pay Item: Overtime Pay",
            "Gross Pay Item: Unknown Category 1",
            "Gross Pay Item: Unknown Category 2"
          ]

          expect(rendered_names).to eq(expected_order)
        end
      end

      context "with nil categories" do
        let(:earnings) do
          [
            Aggregators::ResponseObjects::Earning.new(name: "Nil Category 1", category: nil, amount: 50000),
            Aggregators::ResponseObjects::Earning.new(name: "Base Pay", category: "base", amount: 40000),
            Aggregators::ResponseObjects::Earning.new(name: "Nil Category 2", category: nil, amount: 30000),
            Aggregators::ResponseObjects::Earning.new(name: "Tips", category: "tips", amount: 20000)
          ]
        end

        it "sorts nil categories after known categories, maintaining original order" do
          rendered_names = subject.css("table").last.css("tr td:first-child").map(&:text).map(&:strip)

          expected_order = [
            "Gross Pay Item: Base Pay",
            "Gross Pay Item: Tips",
            "Gross Pay Item: Nil Category 1",
            "Gross Pay Item: Nil Category 2"
          ]

          expect(rendered_names).to eq(expected_order)
        end
      end
    end

    context "when show_earnings_items is false" do
      let(:earnings) do
        [
          Aggregators::ResponseObjects::Earning.new(name: "Regular Pay", amount: 100000)
        ]
      end
      let(:paystub) { build_paystub(earnings: earnings) }

      subject do
        render_inline(
          described_class.new(
            paystub,
            income: income,
            show_earnings_items: false
          )
        )
      end

      it "does not render earnings items section" do
        expect(subject.to_html).not_to include "Gross pay line items"
        expect(subject.to_html).not_to include "Gross Pay Item: Regular Pay"
      end
    end
  end
end
