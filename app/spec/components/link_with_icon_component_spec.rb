# frozen_string_literal: true

require "rails_helper"

RSpec.describe LinkWithIconComponent, type: :component do
  describe '#link_with_icon' do
    let(:result) { render_inline(described_class.new('View Details', url: '/details')) }

    it 'outputs a link with link styling' do
      expect(result).to have_element(:a, href: '/details', class: 'usa-link')
      expect(result).to have_text('View Details')
    end

    context 'without url option' do
      it 'raises an ArgumentError' do
        expect { described_class.new('View Details') }.to raise_error(ArgumentError)
      end
    end

    context 'with icon' do
      let(:result) { render_inline(described_class.new('View Details', url: '/details', icon: 'file_download')) }

      it 'outputs a link with icon' do
        expect(result).to have_element(:a, href: '/details', class: 'usa-link')
        expect(result).to have_element(:svg, class: 'usa-icon')
        expect(result).to have_element(:use, href: /.svg#file_download/)
      end
    end

    context 'with variant' do
      let(:result) { render_inline(described_class.new('Cancel', url: '/cancel', variant: 'unstyled')) }

      it 'adds variant class' do
        expect(result).to have_element(:a, class: 'usa-link usa-link--unstyled')
      end
    end

    context 'with multiple variants' do
      let(:result) { render_inline(described_class.new('Edit', url: '/edit', variant: %w[secondary outline])) }

      it 'adds multiple variant classes' do
        expect(result).to have_element(:a, class: 'usa-link usa-link--secondary usa-link--outline')
      end
    end

    context 'with custom class' do
      let(:result) { render_inline(described_class.new('Download', url: '/download', class: 'download-link')) }

      it 'adds custom class to link' do
        expect(result).to have_element(:a, class: 'usa-link download-link')
      end
    end

    context 'with icon and variant' do
      let(:result) { render_inline(described_class.new('Download', url: '/download', icon: 'file_download', variant: 'accent_cool')) }

      it 'outputs link with both icon and variant styling' do
        expect(result).to have_element(:a, href: '/download', class: 'usa-link usa-link--accent-cool')
        expect(result).to have_element(:use, href: /.svg#file_download/)
      end
    end

    context 'with underscored variant name' do
      let(:result) { render_inline(described_class.new('Test', url: '/test', variant: 'accent_warm')) }

      it 'converts underscores to dashes in CSS class' do
        expect(result).to have_element(:a, class: 'usa-link usa-link--accent-warm')
      end
    end
  end
end
