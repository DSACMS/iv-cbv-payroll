# frozen_string_literal: true

require "rails_helper"

RSpec.describe AggregateDataPointComponent, type: :component do
  describe "#pay_period" do
    it "renders with valid dates" do
      expect(
        render_inline(described_class.new(:pay_period, "2024-01-01", "2024-01-15"))
      ).to have_text(
        "January 1, 2024 to January 15, 2024"
      )
    end
  end

  describe "#pay_gross" do
    it "renders with valid amount" do
      expect(
        render_inline(described_class.new(:pay_gross, 10000))
      ).to have_text(
        "$100.00"
      )
    end
  end

  describe "#net_pay_amount" do
    it "renders with valid amount" do
      expect(
        render_inline(described_class.new(:net_pay_amount, 10000))
      ).to have_text(
        "$100.00"
      )
    end
  end

  describe "#number_of_hours_worked" do
    it "renders with valid hours" do
      expect(
        render_inline(described_class.new(:number_of_hours_worked, 20))
      ).to have_text(
        "20.0 hours"
      )
    end
  end

  describe "#deduction" do
    it "renders with valid data" do
      expect(
        render_inline(described_class.new(:deduction, "health_insurance", "post_tax", 10000))
      ).to have_text(
        "Health insurance (post-tax)\n    $100.00\n\n\n"
      )
    end
  end

  describe "#pay_gross_ytd" do
    it "renders with valid amount" do
      expect(
        render_inline(described_class.new(:pay_gross_ytd, 10000))
      ).to have_text(
        "$100.00"
      )
    end
  end

  describe "#employment_start_date" do
    it "renders with valid date" do
      expect(
        render_inline(described_class.new(:employment_start_date, "2024-01-01"))
      ).to have_text(
        "January 1, 2024"
      )
    end

    it "renders N/A for nil date" do
      expect(
        render_inline(described_class.new(:employment_start_date, nil))
      ).to have_text("N/A")
    end
  end

  describe "#employment_end_date" do
    it "renders with valid date" do
      expect(
        render_inline(described_class.new(:employment_end_date, "2024-01-01"))
      ).to have_text(
        "January 1, 2024"
      )
    end

    it "renders N/A for nil date" do
      expect(
        render_inline(described_class.new(:employment_end_date, nil))
      ).to have_text("N/A")
    end
  end

  describe "#employment_status" do
    it "renders with valid status" do
      expect(
        render_inline(described_class.new(:employment_status, "employed"))
      ).to have_text(
        "Employed"
      )
    end

    it "renders N/A for nil status" do
      expect(
        render_inline(described_class.new(:employment_status, nil))
      ).to have_text("N/A")
    end
  end

  describe "#pay_frequency" do
    it "renders with valid frequency" do
      expect(
        render_inline(described_class.new(:pay_frequency, "bi-weekly"))
      ).to have_text(
        "Bi-weekly"
      )
    end

    it "renders N/A for nil frequency" do
      expect(
        render_inline(described_class.new(:pay_frequency, nil))
      ).to have_text("N/A")
    end
  end

  describe "#hourly_rate" do
    it "renders with valid data" do
      expect(
        render_inline(described_class.new(:hourly_rate, 10000, "hourly"))
      ).to have_text(
        "$100.00 Hourly"
      )
    end
  end

  describe "#employer_phone" do
    it "renders with valid phone number" do
      expect(
        render_inline(described_class.new(:employer_phone, "+19876543211"))
      ).to have_text(
        "+1987-654-3211"
      )
    end

    it "renders N/A for nil phone number" do
      expect(
        render_inline(described_class.new(:employer_phone, nil))
      ).to have_text("N/A")
    end
  end

  describe "#employer_address" do
    it "renders with valid address" do
      expect(
        render_inline(described_class.new(:employer_address, "742 Evergreen Terrace"))
      ).to have_text(
        "742 Evergreen Terrace"
      )
    end

    it "renders N/A for nil address" do
      expect(
        render_inline(described_class.new(:employer_address, nil))
      ).to have_text("N/A")
    end
  end

  describe "highlighting" do
    it "highlights text when highlight: true" do
      expect(render_inline(described_class.new(:employer_address, "742 Evergreen Terrace")).to_html).not_to include("cbv-row-highlight")
      expect(render_inline(described_class.new(:employer_address, "742 Evergreen Terrace", highlight: true)).to_html).to include("cbv-row-highlight")
    end
  end
end
