# frozen_string_literal: true

module Uswds
  class CardPreview < ApplicationPreview
    # @param heading_text text
    # @param body text
    def default(heading_text: "Card heading", body: "Lorem ipsum dolor sit amet consectetur adipisicing elit.")
      render(Uswds::Card.new(heading_text: heading_text)) do |card|
        card.with_body { body }
      end
    end

    def community_service
      render(Uswds::Card.new(heading_text: "Community Service")) do |card|
        card.with_body do
          safe_join([
            hours_month_section("January 2026", "20"),
            hours_month_section("December 2025", "15"),
            hours_month_section("November 2025", "18")
          ])
        end
        card.with_footer { tag.a("Edit", href: "#") }
      end
    end

    def work_program
      render(Uswds::Card.new(heading_text: "Work Program")) do |card|
        card.with_body do
          safe_join([
            hours_month_section("January 2026", "20"),
            hours_month_section("December 2025", "15"),
            hours_month_section("November 2025", "18")
          ])
        end
        card.with_footer { tag.a("Edit", href: "#") }
      end
    end

    def employment
      render(Uswds::Card.new(heading_text: "Employment")) do |card|
        card.with_body do
          safe_join([
            employment_month_section("January 2026", "$2,400", "160"),
            employment_month_section("December 2025", "$2,200", "150"),
            employment_month_section("November 2025", "$2,100", "145")
          ])
        end
        card.with_footer { tag.a("Edit", href: "#") }
      end
    end

    def education
      render(Uswds::Card.new(heading_text: "Education")) do |card|
        card.with_body do
          safe_join([
            month_section("January 2026", "Enrolled", "12"),
            month_section("December 2025", "Enrolled", "15"),
            month_section("November 2025", "Not enrolled", "0")
          ])
        end
        card.with_footer { tag.a("Edit", href: "#") }
      end
    end

    private

    def employment_month_section(month, gross_income, hours)
      tag.div(class: "margin-bottom-2") do
        safe_join([
          tag.p(tag.strong(month), class: "margin-y-0"),
          tag.p("Gross income: #{gross_income}", class: "margin-y-0"),
          tag.p("Hours: #{hours}", class: "margin-y-0")
        ])
      end
    end

    def hours_month_section(month, hours)
      tag.div(class: "margin-bottom-2") do
        safe_join([
          tag.p(tag.strong(month), class: "margin-y-0"),
          tag.p("Hours: #{hours}", class: "margin-y-0")
        ])
      end
    end

    def month_section(month, status, hours)
      tag.div(class: "margin-bottom-2") do
        safe_join([
          tag.p(tag.strong(month), class: "margin-y-0"),
          tag.p("Enrollment status: #{status}", class: "margin-y-0"),
          tag.p("Credit hours: #{hours}", class: "margin-y-0")
        ])
      end
    end
  end
end
