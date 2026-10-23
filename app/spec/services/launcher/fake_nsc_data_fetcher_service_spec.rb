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
    context "when enrollment is verified without an intensity" do
      let(:identity) do
        create(:identity, first_name: "Jordan", last_name: "Testuser", date_of_birth: Date.new(1995, 6, 12))
      end

      before { service.fetch }

      it "saves enrolled status across the reporting window" do
        expect(education_activity.reload).to be_sync_succeeded
        expect(education_activity.nsc_enrollment_terms.sole).to have_attributes(
          school_name: "Maple Grove College",
          enrollment_status: "enrolled",
          term_begin: activity_flow.reporting_window_range.begin,
          term_end: activity_flow.reporting_window_range.end
        )
      end

      it "requires self-attested credits rather than validating half-time enrollment" do
        expect(education_activity.reload).to be_partially_self_attested
        expect(education_activity).to have_less_than_half_time_terms
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
