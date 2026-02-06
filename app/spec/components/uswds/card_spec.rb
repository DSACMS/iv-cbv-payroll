# frozen_string_literal: true

require "rails_helper"

RSpec.describe Uswds::Card, type: :component do
  it "renders a basic card with body content" do
    result = render_inline(described_class.new) do |card|
      card.with_body { "Card body content" }
    end

    expect(result).to have_element(:div, class: "usa-card")
    expect(result).to have_element(:div, class: "usa-card__container")
    expect(result).to have_element(:div, class: "usa-card__body")
    expect(result).to have_text("Card body content")
  end

  context "with heading" do
    it "renders a header with heading text" do
      result = render_inline(described_class.new(heading_text: "Card Title")) do |card|
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card__header")
      expect(result).to have_element(:h2, class: "usa-card__heading")
      expect(result).to have_text("Card Title")
    end

    it "supports custom heading levels" do
      result = render_inline(described_class.new(heading_text: "Card Title", heading_level: 4)) do |card|
        card.with_body { "Body" }
      end

      expect(result).to have_element(:h4, class: "usa-card__heading")
    end
  end

  context "with header slot" do
    it "renders custom header content" do
      result = render_inline(described_class.new) do |card|
        card.with_header { "Custom header content" }
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card__header")
      expect(result).to have_text("Custom header content")
    end
  end

  context "with media slot" do
    it "renders media content" do
      result = render_inline(described_class.new) do |card|
        card.with_media { '<img src="test.png" alt="Test" />'.html_safe }
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card__media")
      expect(result).to have_element(:div, class: "usa-card__img")
    end
  end

  context "with footer slot" do
    it "renders footer content" do
      result = render_inline(described_class.new) do |card|
        card.with_body { "Body" }
        card.with_footer { "Footer content" }
      end

      expect(result).to have_element(:div, class: "usa-card__footer")
      expect(result).to have_text("Footer content")
    end
  end

  context "flag variant" do
    it "adds flag class" do
      result = render_inline(described_class.new(flag: true)) do |card|
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card usa-card--flag")
    end
  end

  context "header-first variant" do
    it "adds header-first class" do
      result = render_inline(described_class.new(header_first: true)) do |card|
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card usa-card--header-first")
    end
  end

  context "media-right variant" do
    it "adds media-right class" do
      result = render_inline(described_class.new(media_right: true)) do |card|
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card usa-card--media-right")
    end
  end

  context "with custom class" do
    it "appends custom class" do
      result = render_inline(described_class.new(class: "custom-card")) do |card|
        card.with_body { "Body" }
      end

      expect(result).to have_element(:div, class: "usa-card custom-card")
    end
  end
end
