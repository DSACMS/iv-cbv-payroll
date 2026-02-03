# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityFlowProgressIndicator, type: :component do
  let(:reporting_month) { Date.new(2026, 1, 1) }
  let(:expected_title) do
    I18n.t(
      "activity_flow_progress_indicator.title",
      month: I18n.l(reporting_month, format: :month)
    )
  end

  it "renders the title and description" do
    render_inline(described_class.new(hours: 40, reporting_month: reporting_month))

    expect(page).to have_css("h2", text: expected_title)
    expect(page).to have_content(I18n.t("activity_flow_progress_indicator.description"))
  end

  it "renders the completion threshold and hours label" do
    render_inline(described_class.new(hours: 40, reporting_month: reporting_month))

    expect(page).to have_content(
      "#{ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD} " \
      "#{I18n.t("activity_flow_progress_indicator.hours")}"
    )
  end

  it "adds the percent complete as a data attribute" do
    render_inline(described_class.new(hours: 40, reporting_month: reporting_month))

    progress = page.find(:css, ".activity-flow-progress-indicator__progress-bar")
    expect(progress["data-percent"]).to eq("50.0")
  end

  it "renders whole hours without decimals" do
    render_inline(described_class.new(hours: 40, reporting_month: reporting_month))

    expect(page).to have_css(
      ".activity-flow-progress-indicator__progress-amount",
      text: "40"
    )
  end

  it "rounds fractional hours to one decimal" do
    render_inline(described_class.new(hours: 10.55, reporting_month: reporting_month))

    expect(page).to have_css(
      ".activity-flow-progress-indicator__progress-amount",
      text: "10.6"
    )
  end
end
