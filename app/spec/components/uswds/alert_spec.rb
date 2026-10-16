# frozen_string_literal: true

require "rails_helper"

RSpec.describe Uswds::Alert, type: :component do
  let(:result) { render_inline(described_class.new) { 'Alert message' } }

  it 'outputs an alert with default info styling' do
    expect(result).to have_element(:div, class: 'usa-alert usa-alert--info')
    expect(result).to have_element(:div, class: 'usa-alert__body')
    expect(result).to have_element(:div, class: 'usa-alert__text')
    expect(result).to have_text('Alert message')
  end

  it "renders an accessible alert" do
    result = render_inline(described_class.new(type: :error)) do
      "Your session has expired"
    end

    expect(result).to have_css(".usa-alert[role='alert'][aria-atomic='true']")
    expect(result).to have_text("Your session has expired")
  end

  context 'with type option' do
    let(:result) { render_inline(described_class.new(type: :warning)) { 'Warning message' } }

    it 'applies the correct alert type class' do
      expect(result).to have_element(:div, class: 'usa-alert usa-alert--warning')
      expect(result).to have_text('Warning message')
    end
  end

  context 'with heading' do
    let(:result) { render_inline(described_class.new(heading: 'Important Notice')) { 'Alert content' } }

    it 'outputs alert with heading' do
      expect(result).to have_element(:div, class: 'usa-alert__heading')
      expect(result).to have_text('Important Notice')
      expect(result).to have_text('Alert content')
    end
  end

  context 'with custom class' do
    let(:result) { render_inline(described_class.new(class: 'custom-alert')) { 'Custom alert' } }

    it 'adds custom class to alert' do
      expect(result).to have_element(:div, class: 'usa-alert usa-alert--info custom-alert')
    end
  end

  context 'slim variant' do
    let(:result) { render_inline(described_class.new(slim: true)) { 'Custom alert' } }

    it 'adds slim class to alert' do
      expect(result).to have_element(:div, class: 'usa-alert usa-alert--info usa-alert--slim')
    end
  end

  context "with an associated form" do
    let(:result) do
      render_inline(
        described_class.new(
          type: :error,
          heading: "Check your entries",
          form_id: "work-form"
        )
      ) { "Correct the errors below." }
    end

    it "renders a focusable summary instead of a live alert" do
      expect(result).to have_css(
        '.usa-alert[role="group"][tabindex="-1"]' \
        '[data-controller="error-summary"]' \
        '[data-error-summary-form-id-value="work-form"]'
      )
      expect(result).to have_no_css('[role="alert"]')
    end

    it "connects the summary to its heading and body" do
      expect(result).to have_css(
        '.usa-alert[aria-labelledby="work-form_error_heading"]' \
        '[aria-describedby="work-form_error_body"]'
      )
      expect(result).to have_css(
        "#work-form_error_heading",
        text: "Check your entries"
      )
      expect(result).to have_css(
        '#work-form_error_body[data-error-summary-target="body"]',
        text: "Correct the errors below."
      )
    end

    it "renders the heading once without exposing attribute text" do
      expect(result).to have_text("Check your entries", count: 1)
      expect(result).to have_no_text('id="work-form_error_heading"')
    end

    context "without a heading" do
      let(:result) do
        render_inline(
          described_class.new(type: :error, form_id: "work-form")
        ) { "Correct the errors below." }
      end

      it "does not reference a missing heading" do
        expect(result).to have_no_css("[aria-labelledby]")
        expect(result).to have_css(
          '.usa-alert[aria-describedby="work-form_error_body"]'
        )
      end
    end
  end

  context "without an associated form" do
    it "does not attach summary focus behavior" do
      expect(result).to have_css('.usa-alert[role="alert"]')
      expect(result).to have_no_css('[data-controller~="error-summary"]')
      expect(result).to have_no_css("[tabindex]")
    end
  end
end
