# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityFlowProgressIndicator, type: :component do
  subject(:component) do
    described_class.new(
      monthly_calculation_results: monthly_calculation_results,
      variant: variant,
      required_month_count: required_month_count,
      show_unit_toggle: show_unit_toggle,
      display_variant: display_variant
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
  let(:show_unit_toggle) { false }
  let(:display_variant) { :default }
  let(:expected_title) do
    I18n.t(
      "activity_flow_progress_indicator.title",
      month: I18n.l(reporting_month, format: :month)
    )
  end

  describe ".from_calculator" do
    it "uses the calculator required_month_count" do
      monthly_results = [
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 12, 1),
          total_hours: 84,
          meets_requirements: true
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2026, 1, 1),
          total_hours: 20,
          meets_requirements: false
        )
      ]
      calculator = instance_double(
        ActivityFlowProgressCalculator,
        monthly_results: monthly_results,
        required_month_count: 1
      )

      render_inline(described_class.from_calculator(calculator, variant: :renewal))

      expect(page).to have_css("h2", text: "1/1 months completed")
    end

    it "passes show_unit_toggle through to the component" do
      monthly_results = [
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2026, 1, 1),
          total_hours: 40,
          total_earnings_cents: 500_00,
          default_unit: :hours,
          meets_requirements: false
        )
      ]
      calculator = instance_double(
        ActivityFlowProgressCalculator,
        monthly_results: monthly_results,
        required_month_count: 1
      )

      render_inline(described_class.from_calculator(calculator, show_unit_toggle: true))

      expect(page).to have_button(I18n.t("activity_flow_progress_indicator.switch_to_dollars"))
    end

    it "forwards display_variant" do
      monthly_results = [
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 12, 1),
          total_hours: 84,
          meets_requirements: true
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2026, 1, 1),
          total_hours: 20,
          meets_requirements: false
        )
      ]
      calculator = instance_double(
        ActivityFlowProgressCalculator,
        monthly_results: monthly_results,
        required_month_count: 1
      )

      render_inline(described_class.from_calculator(calculator, display_variant: :review))

      expect(page).to have_css(".activity-flow-progress-indicator__card--review")
    end
  end

  context "when display variant is review" do
    let(:display_variant) { :review }
    let(:monthly_calculation_results) do
      [
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2025, 12, 1),
          total_hours: 20,
          meets_requirements: false
        ),
        ActivityFlowProgressCalculator::MonthlyResult.new(
          month: Date.new(2026, 1, 1),
          total_hours: 84,
          meets_requirements: true
        )
      ]
    end

    it "renders a review-width card with the months completed title" do
      render_inline(component)

      expect(page).to have_css(".activity-flow-progress-indicator__card--review")
      expect(page).to have_css("h2", text: "1/2 months completed")
      expect(page).to have_css(".activity-flow-progress-indicator__progress-bar", count: 2)
    end

    context "when there is a single incomplete month" do
      let(:monthly_calculation_results) do
        [
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2026, 1, 1),
            total_hours: 20,
            meets_requirements: false
          )
        ]
      end

      it "uses the months completed title on the review page" do
        render_inline(component)

        expect(page).to have_css("h2.activity-flow-progress-indicator__title", text: "0/1 months completed")
      end
    end

    context "when unit toggle is enabled for incomplete months" do
      let(:show_unit_toggle) { true }
      let(:monthly_calculation_results) do
        [
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 12, 1),
            total_hours: 40,
            total_earnings_cents: 500_00,
            default_unit: :hours,
            meets_requirements: false
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2026, 1, 1),
            total_hours: 20,
            total_earnings_cents: 200_00,
            default_unit: :hours,
            meets_requirements: false
          )
        ]
      end

      it "renders the toggle inside the review card" do
        render_inline(component)

        expect(page).to have_css(".activity-flow-progress-indicator__card--review [data-controller='progress-indicator-units']")
        expect(page).to have_button(I18n.t("activity_flow_progress_indicator.see_progress_in_dollars"))
      end
    end

    context "when all months are complete" do
      let(:monthly_calculation_results) do
        [
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 12, 1),
            total_hours: 84,
            meets_requirements: true
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2026, 1, 1),
            total_hours: 90,
            meets_requirements: true
          )
        ]
      end

      it "renders the collapsed completed message instead of progress bars" do
        render_inline(component)

        expect(page).to have_css(".activity-flow-progress-indicator--review-collapsed", text: "2/2 months completed")
        expect(page).not_to have_css(".activity-flow-progress-indicator__progress-bar")
      end

      it "does not render the unit toggle controller in the collapsed state" do
        render_inline(component)

        expect(page).not_to have_css("[data-controller='progress-indicator-units']")
        expect(page).not_to have_css("[data-progress-indicator-units-target='toggle']")
      end
    end
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

  context "when unit toggle is enabled for a single incomplete month" do
    let(:show_unit_toggle) { true }
    let(:monthly_result) do
      ActivityFlowProgressCalculator::MonthlyResult.new(
        month: reporting_month,
        total_hours: 40,
        total_earnings_cents: 500_00,
        default_unit: :hours,
        meets_requirements: false
      )
    end

    it "renders the single-month toggle in place of the label area" do
      render_inline(component)

      expect(page).to have_button(I18n.t("activity_flow_progress_indicator.switch_to_dollars"))
      hours_unit_content_text = page
        .all("[data-progress-indicator-units-target='unitContent'][data-unit='hours']", visible: :all)
        .map { |node| node.text.squish }
      dollars_unit_content_text = page
        .all("[data-progress-indicator-units-target='unitContent'][data-unit='dollars'][hidden]", visible: :all)
        .map { |node| node.text.squish }

      expect(hours_unit_content_text).to include(
        "40 / #{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
        "#{I18n.t("activity_flow_progress_indicator.hours")}"
      )
      expect(dollars_unit_content_text).to include("$500 / $580")
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
      expect(row_text).to include(
        "82 / #{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
        "#{I18n.t("activity_flow_progress_indicator.hours")}"
      )
      expect(row_text).not_to include("$620 / $580")
    end
  end

  context "when a completed month omits default_unit" do
    let(:monthly_result) do
      ActivityFlowProgressCalculator::MonthlyResult.new(
        month: reporting_month,
        total_hours: 84,
        total_earnings_cents: 620_00,
        default_unit: nil,
        meets_requirements: true
      )
    end

    it "falls back to hours for the completed-month unit label" do
      render_inline(component)

      row_text = page.find(".activity-flow-progress-indicator__progress-amount-container").text.squish
      expect(row_text).to include(
        "84 / #{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
        "#{I18n.t("activity_flow_progress_indicator.hours")}"
      )
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

    context "when unit toggle is enabled" do
      let(:show_unit_toggle) { true }
      let(:monthly_calculation_results) do
        [
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 12, 1),
            total_hours: 40,
            total_earnings_cents: 500_00,
            default_unit: :hours,
            meets_requirements: false
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 11, 1),
            total_hours: 77,
            total_earnings_cents: 597_00,
            default_unit: :dollars,
            meets_requirements: true
          ),
          ActivityFlowProgressCalculator::MonthlyResult.new(
            month: Date.new(2025, 10, 1),
            total_hours: 10,
            total_earnings_cents: 200_00,
            default_unit: :hours,
            meets_requirements: false
          )
        ]
      end

      it "renders the multi-month toggle link" do
        render_inline(component)

        expect(page).to have_button(I18n.t("activity_flow_progress_indicator.see_progress_in_dollars"))
      end

      it "shows incomplete months in hours by default and keeps completed months frozen" do
        render_inline(component)
        rows = page.all(".activity-flow-progress-indicator__progress-amount-container")
        expect(rows.length).to eq(3)

        expect(rows[0].text).to include("October")
        october_hours_content_text = rows[0]
          .all("[data-progress-indicator-units-target='unitContent'][data-unit='hours']", visible: :all)
          .map { |node| node.text.squish }
        expect(october_hours_content_text).to include(
          "10 / #{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
          "#{I18n.t("activity_flow_progress_indicator.hours")}"
        )
        expect(rows[1].text.squish).to include("November")
        expect(rows[1].text.squish).to include("$597 / $580")
        expect(rows[2].text).to include("December")
        december_hours_content_text = rows[2]
          .all("[data-progress-indicator-units-target='unitContent'][data-unit='hours']", visible: :all)
          .map { |node| node.text.squish }
        expect(december_hours_content_text).to include(
          "40 / #{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
          "#{I18n.t("activity_flow_progress_indicator.hours")}"
        )
      end
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

    context "when unit toggle is enabled" do
      let(:show_unit_toggle) { true }

      it "renders the toggle link for renewal" do
        render_inline(component)

        expect(page).to have_button(I18n.t("activity_flow_progress_indicator.see_progress_in_dollars"))
      end
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

    context "when display variant is review and requirements are met" do
      let(:display_variant) { :review }

      it "uses required_month_count in the collapsed review message" do
        render_inline(component)

        expect(page).to have_css(".activity-flow-progress-indicator--review-collapsed")
        expect(page).to have_css("p.activity-flow-progress-indicator__title", text: "4/3 months completed")
      end
    end

    context "when display variant is review and the renewal is incomplete" do
      let(:display_variant) { :review }
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

      it "omits the renewal subtitle on the review page" do
        render_inline(component)

        expect(page).not_to have_css(".activity-flow-progress-indicator__description")
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
