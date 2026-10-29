require "rails_helper"

RSpec.describe Launcher::FakeNscDataFetcherService do
  subject(:service) { described_class.new(education_activity: education_activity, logger: logger) }

  let(:logger) { Logger.new(StringIO.new) }
  let(:identity) do
    create(
      :identity,
      first_name: "Casey",
      last_name: "Testuser",
      date_of_birth: Date.parse("1991-04-22")
    )
  end
  let(:activity_flow) do
    create(
      :activity_flow,
      identity: identity,
      education_activities_count: 0,
      created_at: Date.new(2026, 3, 1),
      reporting_window_months: 2
    )
  end
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

  describe "#fetch" do
    context "with duplicate enrollment records" do
      let(:profile) { Launcher::FakeNscScenarios.by_key("duplicate_enrollments_dedupe") }
      let(:identity) do
        create(:identity, first_name: profile.first_name, last_name: profile.last_name, date_of_birth: profile.date_of_birth)
      end
      let(:reporting_window) { activity_flow.reporting_window_range }

      before do
        activity_flow.update!(reporting_window_months: 3)
      end

      it "removes duplicate F and S records while preserving W and the distinct A record" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms).to contain_exactly(
          have_attributes(
            term_begin: reporting_window.begin, term_end: reporting_window.end,
            enrollment_status: "full_time", school_certified_on: reporting_window.begin + 1.month
          ),
          have_attributes(
            term_begin: reporting_window.begin, term_end: reporting_window.end,
            enrollment_status: "withdrawn", school_certified_on: reporting_window.begin + 2.months
          ),
          have_attributes(
            term_begin: reporting_window.begin, term_end: reporting_window.end,
            enrollment_status: "leave_of_absence", school_certified_on: reporting_window.begin + 2.months
          )
        )
      end
    end

    context "with Maya's same-school enrollments in distinct terms" do
      let(:profile) { Launcher::FakeNscScenarios.by_key("partial_enrollment_maya") }
      let(:identity) do
        create(:identity, first_name: profile.first_name, last_name: profile.last_name, date_of_birth: profile.date_of_birth)
      end

      it "preserves both distinct terms" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms).to contain_exactly(
          have_attributes(
            term_begin: Date.new(2026, 1, 1), term_end: Date.new(2026, 1, 31),
            school_name: profile.terms.first.fetch(:school_name), enrollment_status: "less_than_half_time"
          ),
          have_attributes(
            term_begin: Date.new(2026, 1, 1), term_end: Date.new(2026, 2, 28),
            school_name: profile.terms.first.fetch(:school_name), enrollment_status: "less_than_half_time"
          )
        )
      end

      context "with a six-month reporting window" do
        before do
          activity_flow.update!(reporting_window_months: 6)
        end

        it "keeps enrollment covering the full reporting window" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms).to contain_exactly(
            have_attributes(term_begin: Date.new(2025, 9, 1), term_end: Date.new(2025, 9, 30)),
            have_attributes(term_begin: Date.new(2025, 9, 1), term_end: Date.new(2026, 2, 28))
          )
        end
      end
    end

    it "saves fake enrollment terms and derives data_source from those terms" do
      expect { service.fetch }
        .to change { education_activity.reload.status }
        .from("unknown").to("succeeded")
        .and change { education_activity.nsc_enrollment_terms.count }.by(2)

      statuses = education_activity.nsc_enrollment_terms.pluck(:enrollment_status)
      expect(statuses).to contain_exactly("half_time", "less_than_half_time")
      expect(education_activity.reload.data_source).to eq("validated")
    end

    context "when half-time coverage only spans part of the reporting window" do
      let(:identity) do
        create(
          :identity,
          first_name: "Taylor",
          last_name: "Testuser",
          date_of_birth: Date.parse("1994-03-08")
        )
      end

      it "sets data_source to partially_self_attested" do
        service.fetch

        expect(education_activity.reload.data_source).to eq("partially_self_attested")
      end
    end

    context "with spring and fall terms but no summer term" do
      let(:identity) do
        create(
          :identity,
          first_name: "Morgan",
          last_name: "Testuser",
          date_of_birth: Date.parse("1994-12-09")
        )
      end
      let(:activity_flow) do
        create(
          :activity_flow,
          identity: identity,
          education_activities_count: 0,
          created_at: Date.new(2025, 10, 1),
          reporting_window_months: 4
        )
      end

      it "sets data_source to validated" do
        service.fetch

        expect(education_activity.reload.data_source).to eq("validated")
      end
    end
  end
end
