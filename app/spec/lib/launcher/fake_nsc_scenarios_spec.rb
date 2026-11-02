require "rails_helper"

RSpec.describe Launcher::FakeNscScenarios do
  describe ".nsc_response_for" do
    context "with duplicate enrollment records" do
      let(:profile) { described_class.by_key("duplicate_enrollments_dedupe") }
      let(:identity) do
        build(:identity, first_name: profile.first_name, last_name: profile.last_name, date_of_birth: profile.date_of_birth)
      end
      let(:reporting_window) { Date.new(2021, 9, 1)..Date.new(2021, 12, 1) }

      it "returns full-time updates, both raw withdrawal codes, and a distinct leave of absence" do
        response = described_class.nsc_response_for(identity: identity, reporting_window: reporting_window)
        records = response.fetch("enrollmentDetails").flat_map { |detail| detail.fetch("enrollmentData") }

        expect(records.map { |record| record.values_at("termBeginDate", "termEndDate", "enrollmentStatus", "schoolCertifiedOnDate") })
          .to contain_exactly(
            [ "2021-09-01", "2021-12-01", "W", "2021-11-01" ],
            [ "2021-09-01", "2021-12-01", "F", "2021-10-01" ],
            [ "2021-09-01", "2021-12-01", "F", "2021-09-01" ],
            [ "2021-09-01", "2021-12-01", "S", "2021-10-01" ],
            [ "2021-09-01", "2021-12-01", "A", "2021-11-01" ]
          )
      end
    end

    it "limits Nina's terms to the last 2 months of the reporting window" do
      identity = build(
        :identity,
        first_name: "Nina",
        last_name: "Testuser",
        date_of_birth: Date.parse("1990-05-15")
      )
      reporting_window = Date.new(2025, 9, 1)..Date.new(2026, 2, 28) # 6 months

      response = described_class.nsc_response_for(identity: identity, reporting_window: reporting_window)
      term_ranges = response.fetch("enrollmentDetails").flat_map do |enrollment|
        enrollment.fetch("enrollmentData").map do |term|
          Date.parse(term.fetch("termBeginDate"))..Date.parse(term.fetch("termEndDate"))
        end
      end

      expect(term_ranges.map(&:begin).min).to eq(Date.new(2026, 1, 1))
      expect(term_ranges.map(&:end).max).to eq(Date.new(2026, 2, 28))
    end

    it "builds Taylor with half-time only in the first month and less-than-half-time across the window" do
      identity = build(
        :identity,
        first_name: "Taylor",
        last_name: "Testuser",
        date_of_birth: Date.parse("1994-03-08")
      )
      reporting_window = Date.new(2026, 1, 1)..Date.new(2026, 2, 28)

      response = described_class.nsc_response_for(identity: identity, reporting_window: reporting_window)
      terms = response.fetch("enrollmentDetails").flat_map { |enrollment| enrollment.fetch("enrollmentData") }

      half_time = terms.find { |term| term.fetch("enrollmentStatus") == "H" }
      less_than_half_time = terms.find { |term| term.fetch("enrollmentStatus") == "L" }

      expect(Date.parse(half_time.fetch("termBeginDate"))).to eq(Date.new(2026, 1, 1))
      expect(Date.parse(half_time.fetch("termEndDate"))).to eq(Date.new(2026, 1, 31))
      expect(Date.parse(less_than_half_time.fetch("termBeginDate"))).to eq(Date.new(2026, 1, 1))
      expect(Date.parse(less_than_half_time.fetch("termEndDate"))).to eq(Date.new(2026, 2, 28))
    end

    it "builds Sage with a spring term and a summer less-than-half-time term" do
      identity = build(
        :identity,
        first_name: "Sage",
        last_name: "Testuser",
        date_of_birth: Date.parse("1994-08-03")
      )
      reporting_window = Date.new(2025, 7, 1)..Date.new(2025, 8, 31)

      response = described_class.nsc_response_for(identity: identity, reporting_window: reporting_window)
      terms = response.fetch("enrollmentDetails").flat_map { |enrollment| enrollment.fetch("enrollmentData") }

      expect(terms).to include(
        a_hash_including(
          "termBeginDate" => "2025-03-01",
          "termEndDate" => "2025-06-15",
          "enrollmentStatus" => "H"
        ),
        a_hash_including(
          "termBeginDate" => "2025-07-01",
          "termEndDate" => "2025-08-15",
          "enrollmentStatus" => "L"
        )
      )
    end

    it "builds Morgan with spring and fall terms but no summer term" do
      identity = build(
        :identity,
        first_name: "Morgan",
        last_name: "Testuser",
        date_of_birth: Date.parse("1994-12-09")
      )
      reporting_window = Date.new(2025, 6, 1)..Date.new(2025, 9, 30)

      response = described_class.nsc_response_for(identity: identity, reporting_window: reporting_window)
      terms = response.fetch("enrollmentDetails").flat_map { |enrollment| enrollment.fetch("enrollmentData") }

      expect(terms).to include(
        a_hash_including(
          "termBeginDate" => "2025-03-01",
          "termEndDate" => "2025-06-15",
          "enrollmentStatus" => "H"
        ),
        a_hash_including(
          "termBeginDate" => "2025-09-01",
          "termEndDate" => "2025-12-15",
          "enrollmentStatus" => "H"
        )
      )
      expect(terms).not_to include(
        a_hash_including(
          "termBeginDate" => "2025-07-01",
          "termEndDate" => "2025-08-15"
        )
      )
    end

    it "limits Avery's half-time term to the last 4 months of a 6-month reporting window" do
      identity = build(
        :identity,
        first_name: "Avery",
        last_name: "Testuser",
        date_of_birth: Date.parse("1992-11-30")
      )
      reporting_window = Date.new(2025, 9, 1)..Date.new(2026, 2, 28)

      response = described_class.nsc_response_for(identity: identity, reporting_window: reporting_window)
      terms = response.fetch("enrollmentDetails").flat_map { |enrollment| enrollment.fetch("enrollmentData") }

      expect(terms).to include(
        a_hash_including(
          "termBeginDate" => "2025-11-01",
          "termEndDate" => "2026-02-28",
          "enrollmentStatus" => "H"
        )
      )
    end
  end
end
