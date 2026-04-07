# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityFlowProgressIndicator, type: :component do
  subject(:component) do
    described_class.new(
      monthly_calculation_results: monthly_calculation_results,
      agency_full_name: "Test Agency",
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
  let(:variant) { :standard }
  let(:required_month_count) { nil }
  let(:expected_title) do
    I18n.t(
      "activity_flow_progress_indicator.title",
      month: I18n.l(reporting_month, format: :month)
    )
  end

  it "renders the title and description" do
    render_inline(component)

    expect(page).to have_css("h2", text: expected_title)
    expect(page).to have_content(I18n.t("activity_flow_progress_indicator.description"))
  end

  it "renders inside a card component" do
    render_inline(component)

    expect(page).to have_css(".usa-card.activity-flow-progress-indicator__card")
  end

  it "renders the completion threshold and hours label" do
    render_inline(component)

    expect(page).to have_content(
      "#{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
      "#{I18n.t("activity_flow_progress_indicator.hours")}"
    )
  end

  it "adds the percent complete as a style attribute" do
    render_inline(component)

    progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar-fill")
    expect(progress["style"]).to eq("width: 50.0%")
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

    it "renders the 'completed' copy variants for header and description" do
      render_inline(component)

      expect(page).to have_text(I18n.t("activity_flow_progress_indicator.title_complete"))
      expect(page).to have_text(I18n.t("activity_flow_progress_indicator.description_complete", agency_full_name: "Test Agency"))
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

    it "falls back to standard rendering" do
      render_inline(component)

      expect(page).to have_css("h2", text: expected_title)
      expect(page).to have_content(I18n.t("activity_flow_progress_indicator.description"))
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
      render_inline(component)

      expect(page).to have_css(".activity-flow-progress-indicator__success-icon")
    end

    it "includes a 'months completed' message" do
      render_inline(component)

      expect(page).to have_css(".activity-flow-progress-indicator", text: "1 / 3 months completed")
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

    it "does not render the default completed copy variants" do
      render_inline(component)

      expect(page).not_to have_text(I18n.t("activity_flow_progress_indicator.title_complete"))
      expect(page).not_to have_text(I18n.t("activity_flow_progress_indicator.description_complete", agency_full_name: "Test Agency"))
    end

    it "does not render the multi-month completion banner copy" do
      render_inline(component)

      expect(page).not_to have_text("1 / 3 months completed")
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
  end
end
