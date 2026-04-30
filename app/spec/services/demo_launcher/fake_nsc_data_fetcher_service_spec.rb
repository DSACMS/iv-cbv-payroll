require "rails_helper"

RSpec.describe DemoLauncher::FakeNscDataFetcherService do
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
  end
end
