# frozen_string_literal: true

require "rails_helper"

RSpec.describe AggregateDataPointComponent, type: :component do
  it "renders pay_period" do
    expect(
      render_inline(described_class.new(:pay_period, "2024-01-01", "2024-01-15"))
    ).to have_text(
      "January 01, 2024 to January 15, 2024"
    )
  end

  it "renders pay_gross" do
    expect(
      render_inline(described_class.new(:pay_gross, 10000))
    ).to have_text(
      "$100.00"
    )
  end

  it "renders net_pay_amount" do
    expect(
      render_inline(described_class.new(:net_pay_amount, 10000))
    ).to have_text(
      "$100.00"
    )
  end

  it "renders number_of_hours_worked" do
    expect(
      render_inline(described_class.new(:number_of_hours_worked, 20))
    ).to have_text(
      "20.0 hours"
    )
  end

  it "renders deduction" do
    expect(
      render_inline(described_class.new(:deduction, "health_insurance", 10000))
    ).to have_text(
      "Health insurance\n    $100.00\n\n\n"
    )
  end

  it "renders pay_gross_ytd" do
    expect(
      render_inline(described_class.new(:pay_gross_ytd, 10000))
    ).to have_text(
      "$100.00"
    )
  end

  it "renders employment_start_date" do
    expect(
      render_inline(described_class.new(:employment_start_date, "2024-01-01"))
    ).to have_text(
      "January 01, 2024"
    )
  end

  it "renders employment_end_date" do
    expect(
      render_inline(described_class.new(:employment_end_date, "2024-01-01"))
    ).to have_text(
      "January 01, 2024"
    )
  end

  it "renders employment_status" do
    expect(
      render_inline(described_class.new(:employment_status, "employed"))
    ).to have_text(
      "Employed"
    )
  end

  it "renders pay_frequency" do
    expect(
      render_inline(described_class.new(:pay_frequency, "bi-weekly"))
    ).to have_text(
      "bi-weekly"
    )
  end

  it "renders hourly_rate" do
    expect(
      render_inline(described_class.new(:hourly_rate, 10000, "hourly"))
    ).to have_text(
      "$100.00 hourly"
    )
  end

  it "renders employer_phone" do
    expect(
      render_inline(described_class.new(:employer_phone, "+19876543211"))
    ).to have_text(
      "+1987-654-3211"
    )
  end

  it "renders employer_address" do
    expect(
      render_inline(described_class.new(:employer_address, "742 Evergreen Terrace"))
    ).to have_text(
      "742 Evergreen Terrace"
    )
  end
end
