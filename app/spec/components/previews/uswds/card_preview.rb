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
      render(Uswds::Card.new(heading_text: "Community Service", class: "activity-hub-card")) do |card|
        card.with_header { tag.a("Edit", href: "#", class: "usa-link") }
        card.with_body do
          safe_join([
            hours_month_section("January 2026", "20"),
            hours_month_section("December 2025", "15"),
            hours_month_section("November 2025", "18")
          ])
        end
      end
    end

    def work_program
      render(Uswds::Card.new(heading_text: "Work Program", class: "activity-hub-card")) do |card|
        card.with_header { tag.a("Edit", href: "#", class: "usa-link") }
        card.with_body do
          safe_join([
            hours_month_section("January 2026", "20"),
            hours_month_section("December 2025", "15"),
            hours_month_section("November 2025", "18")
          ])
        end
      end
    end

    def employment
      render(Uswds::Card.new(heading_text: "Employment", class: "activity-hub-card")) do |card|
        card.with_header { tag.a("Edit", href: "#", class: "usa-link") }
        card.with_body do
          safe_join([
            employment_month_section("January 2026", "$2,400", "160"),
            employment_month_section("December 2025", "$2,200", "150"),
            employment_month_section("November 2025", "$2,100", "145")
          ])
        end
      end
    end

    def education
      render(Uswds::Card.new(heading_text: "Education", class: "activity-hub-card")) do |card|
        card.with_header { tag.a("Edit", href: "#", class: "usa-link") }
        card.with_body do
          safe_join([
            validated_education_month_section("January 2026", "Half-time", "80"),
            validated_education_month_section("December 2025", "Half-time", "80"),
            validated_education_month_section("November 2025", "Not enrolled", "0")
          ])
        end
      end
    end

    # @label Self-attested education
    def self_attested_education
      render(Uswds::Card.new(heading_text: "Education", class: "activity-hub-card")) do |card|
        card.with_header { tag.a("Edit", href: "#", class: "usa-link") }
        card.with_body do
          safe_join([
            self_attested_education_month_section("January 2026", "12", "48"),
            self_attested_education_month_section("December 2025", "9", "36"),
            self_attested_education_month_section("November 2025", "6", "24")
          ])
        end
      end
    end

    private

    def employment_month_section(month, gross_income, hours)
      tag.div(class: "activity-month-details") do
        safe_join([
          tag.div(tag.strong(month), class: "activity-month-details__month"),
          tag.div(class: "activity-month-details__data") do
            safe_join([
              tag.p("Gross income: #{gross_income}", class: "margin-y-0"),
              tag.p("Community engagement hours: #{hours}", class: "margin-y-0")
            ])
          end
        ])
      end
    end

    def hours_month_section(month, hours)
      tag.div(class: "activity-month-details") do
        safe_join([
          tag.div(tag.strong(month), class: "activity-month-details__month"),
          tag.div(class: "activity-month-details__data") do
            tag.p("Community engagement hours: #{hours}", class: "margin-y-0")
          end
        ])
      end
    end

    def validated_education_month_section(month, enrollment_status, hours)
      tag.div(class: "activity-month-details") do
        safe_join([
          tag.div(tag.strong(month), class: "activity-month-details__month"),
          tag.div(class: "activity-month-details__data") do
            safe_join([
              tag.p("Enrollment: #{enrollment_status}", class: "margin-y-0"),
              tag.p("Community engagement hours: #{hours}", class: "margin-y-0")
            ])
          end
        ])
      end
    end

    def self_attested_education_month_section(month, credit_hours, hours)
      tag.div(class: "activity-month-details") do
        safe_join([
          tag.div(tag.strong(month), class: "activity-month-details__month"),
          tag.div(class: "activity-month-details__data") do
            safe_join([
              tag.p("Credit hours: #{credit_hours}", class: "margin-y-0"),
              tag.p("Community engagement hours: #{hours}", class: "margin-y-0")
            ])
          end
        ])
      end
    end
  end
end
