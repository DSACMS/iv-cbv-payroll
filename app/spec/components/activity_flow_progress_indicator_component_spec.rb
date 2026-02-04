# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityFlowProgressIndicator, type: :component do
  let(:reporting_month) { Date.new(2026, 1, 1) }
  let(:monthly_result) do
    ActivityFlowProgressCalculator::MonthlyResult.new(
      month: reporting_month,
      total_hours: hours,
      meets_requirements: hours >= ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD
    )
  end
  let(:monthly_calculation_results) { [ monthly_result ] }
  let(:hours) { 40 }
  let(:expected_title) do
    I18n.t(
      "activity_flow_progress_indicator.title",
      month: I18n.l(reporting_month, format: :month)
    )
  end

  it "renders the title and description" do
    render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

    expect(page).to have_css("h2", text: expected_title)
    expect(page).to have_content(I18n.t("activity_flow_progress_indicator.description"))
  end

  it "renders the completion threshold and hours label" do
    render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

    expect(page).to have_content(
      "#{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
      "#{I18n.t("activity_flow_progress_indicator.hours")}"
    )
  end

  it "adds the percent complete as a data attribute" do
    render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

    progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar")
    expect(progress["data-percent"]).to eq("50.0")
  end

  context "when hours exceed the threshold" do
    let(:hours) { 120 }

    it "caps the percentage complete at 100" do
      render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

      progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar")
      expect(progress["data-percent"]).to eq("100")
    end

    it "displays a success icon" do
      render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

      expect(page).to have_css(".activity-flow-progress-indicator__success-icon")
    end
  end

  it "renders whole hours without decimals" do
    render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

    expect(page).to have_css(
      ".activity-flow-progress-indicator__progress-amount",
      text: "40"
    )
  end

  context "when hours are fractional" do
    let(:hours) { 10.55 }

    it "rounds fractional hours to one decimal" do
      render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

      expect(page).to have_css(
        ".activity-flow-progress-indicator__progress-amount",
        text: "10.6"
      )
    end
  end

  context "when there are multiple monthly resuts" do
    let(:monthly_calculation_results) do
      [
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 12, 1),
          total_hours: 20,
          meets_requirements: false
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 11, 1),
          total_hours: 84,
          meets_requirements: true
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 10, 1),
          total_hours: 10,
          meets_requirements: false
        )
      ]
    end

    it "renders the month names" do
      render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

      expect(page).to have_css(
        ".activity-flow-progress-indicator__progress-amount-container",
        text: "December"
      )
      expect(page).to have_css(
        ".activity-flow-progress-indicator__progress-amount-container",
        text: "November"
      )
      expect(page).to have_css(
        ".activity-flow-progress-indicator__progress-amount-container",
        text: "October"
      )
    end

    it "displays success icons" do
      render_inline(described_class.new(monthly_calculation_results: monthly_calculation_results))

      expect(page).to have_css(".activity-flow-progress-indicator__success-icon")
    end
  end
end
