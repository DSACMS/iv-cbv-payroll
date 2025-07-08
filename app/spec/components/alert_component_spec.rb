# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertComponent, type: :component do
  let(:result) { render_inline(described_class.new) { 'Alert message' } }

  it 'outputs an alert with default info styling' do
    expect(result).to have_element(:div, class: 'usa-alert usa-alert--info')
    expect(result).to have_element(:div, class: 'usa-alert__body')
    expect(result).to have_element(:div, class: 'usa-alert__text')
    expect(result).to have_text('Alert message')
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
      expect(result).to have_element(:h2, class: 'usa-alert__heading')
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
end
