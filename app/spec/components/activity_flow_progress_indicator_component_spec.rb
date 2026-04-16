# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityFlowProgressIndicator, type: :component do
  subject(:component) do
    described_class.new(
      monthly_calculation_results: monthly_calculation_results,
      variant: variant,
      required_month_count: required_month_count
    )
  end

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
  let(:variant) { :application }
  let(:required_month_count) { nil }
  let(:expected_title) do
    I18n.t(
      "activity_flow_progress_indicator.title",
      month: I18n.l(reporting_month, format: :month)
    )
  end

  it "renders the title without description for application variants" do
    render_inline(component)

    expect(page).to have_css("h2", text: expected_title)
    expect(page).not_to have_css(".activity-flow-progress-indicator__description")
  end

  it "renders inside a card component" do
    render_inline(component)

    expect(page).to have_css(".usa-card.activity-flow-progress-indicator__card")
  end

  it "renders the completion threshold and hours label" do
    render_inline(component)

    expect(page.find(".activity-flow-progress-indicator__progress-amount-container")).to have_text(
      "#{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
      "#{I18n.t("activity_flow_progress_indicator.hours")}",
      normalize_ws: true
    )
  end

  it "adds the percent complete as a style attribute" do
    render_inline(component)

    progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar-fill")
    expect(progress["style"]).to eq("width: 50.0%")
  end

  context "when monthly default unit is dollars" do
    let(:monthly_result) do
      ActivityFlowProgressCalculator::MonthlyResult.new(
        month: reporting_month,
        total_hours: 77,
        total_earnings_cents: 597_00,
        default_unit: :dollars,
        meets_requirements: true
      )
    end

    it "renders dollars for amount and threshold" do
      render_inline(component)

      row_text = page.find(".activity-flow-progress-indicator__progress-amount-container").text.squish

      expect(row_text).to include("$597 / $580")
      expect(row_text).not_to include(I18n.t("activity_flow_progress_indicator.hours"))
      expect(page).to have_css(".activity-flow-progress-indicator__progress-bar--complete")
      expect(page).to have_css(".activity-flow-progress-indicator__success-icon")
    end

    it "calculates progress width using dollars threshold" do
      render_inline(component)

      progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar-fill")
      expect(progress["style"]).to eq("width: 100%")
    end
  end

  context "when hours and earnings both meet threshold" do
    let(:monthly_result) do
      ActivityFlowProgressCalculator::MonthlyResult.new(
        month: reporting_month,
        total_hours: 82,
        total_earnings_cents: 620_00,
        default_unit: :hours,
        meets_requirements: true
      )
    end

    it "keeps hours as the rendered unit" do
      render_inline(component)

      row_text = page.find(".activity-flow-progress-indicator__progress-amount-container").text.squish
      expect(row_text).to include("82 / 80 #{I18n.t("activity_flow_progress_indicator.hours")}")
      expect(row_text).not_to include("$620 / $580")
    end
  end

  it "does not show the 'months completed' message" do
    render_inline(component)

    expect(page).not_to have_text("months completed")
  end

  context "when hours exceed the threshold" do
    let(:hours) { 120 }

    it "caps the percentage complete at 100" do
      render_inline(component)

      progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar-fill")
      expect(progress["style"]).to eq("width: 100%")
    end

    it "displays a success icon" do
      render_inline(component)

      expect(page).to have_css(".activity-flow-progress-indicator__success-icon")
    end
  end

  it "renders whole hours without decimals" do
    render_inline(component)

    expect(page).to have_css(
      ".activity-flow-progress-indicator__progress-amount",
      text: "40"
    )
  end

  context "when hours are fractional" do
    let(:hours) { 10.55 }

    it "rounds fractional hours to one decimal" do
      render_inline(component)

      expect(page).to have_css(
        ".activity-flow-progress-indicator__progress-amount",
        text: "10.6"
      )
    end
  end

  context "when variant is unsupported" do
    let(:variant) { :future_variant }

    it "falls back to application rendering" do
      render_inline(component)

      expect(page).to have_css("h2", text: expected_title)
      expect(page).not_to have_css(".activity-flow-progress-indicator__description")
    end
  end

  context "when there are multiple monthly results" do
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
      render_inline(component)

      month_labels = page
        .all(".activity-flow-progress-indicator__progress-amount-container")
        .map { |row| row.find("span", match: :first).text.strip }

      expect(month_labels).to eq([ "October", "November", "December" ])
    end

    it "displays success icons" do
      render_inline(component)

      expect(page).to have_css(".activity-flow-progress-indicator__success-icon")
    end

    it "includes a 'months completed' message" do
      render_inline(component)

      expect(page).to have_css("h2", text: "1/3 months completed")
      expect(page).not_to have_css(".activity-flow-progress-indicator__months-completed")
    end
  end

  context "when variant is renewal" do
    let(:variant) { :renewal }
    let(:required_month_count) { 3 }
    let(:monthly_calculation_results) do
      [
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2026, 1, 1),
          total_hours: 0,
          meets_requirements: false
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 12, 1),
          total_hours: 90,
          meets_requirements: true
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 11, 1),
          total_hours: 95,
          meets_requirements: true
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 10, 1),
          total_hours: 86,
          meets_requirements: true
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 9, 1),
          total_hours: 20,
          meets_requirements: false
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 8, 1),
          total_hours: 88,
          meets_requirements: true
        )
      ]
    end

    it "renders the renewal title and subtitle" do
      render_inline(component)

      expect(page).to have_css("h2", text: "4/3 months completed")
      expect(page).to have_text(
        "Complete any 3 months between August-January to meet requirements."
      )
    end

    it "shows a success icon in the header when renewal requirements are complete" do
      render_inline(component)

      expect(page).to have_css("h2 .activity-flow-progress-indicator__success-icon")
    end

    it "renders renewal months oldest to newest" do
      render_inline(component)

      month_labels = page
        .all(".activity-flow-progress-indicator__progress-amount-container")
        .map { |row| row.find("span", match: :first).text.strip }

      expect(month_labels).to eq([ "August", "September", "October", "November", "December", "January" ])
    end

    context "when completed months are below the required count" do
      let(:monthly_calculation_results) do
        [
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2026, 1, 1),
            total_hours: 0,
            meets_requirements: false
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 12, 1),
            total_hours: 90,
            meets_requirements: true
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 11, 1),
            total_hours: 95,
            meets_requirements: true
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 10, 1),
            total_hours: 40,
            meets_requirements: false
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 9, 1),
            total_hours: 20,
            meets_requirements: false
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 8, 1),
            total_hours: 35,
            meets_requirements: false
          )
        ]
      end

      it "uses required_month_count as the denominator while remaining incomplete" do
        render_inline(component)

        expect(page).to have_css("h2", text: "2/3 months completed")
      end
    end

    context "when required_month_count is omitted" do
      let(:required_month_count) { nil }

      it "defaults required_month_count to the reporting window length" do
        render_inline(component)

        expect(page).to have_css("h2", text: "4/6 months completed")
        expect(page).not_to have_css(".activity-flow-progress-indicator__description")
      end
    end
  end
end
