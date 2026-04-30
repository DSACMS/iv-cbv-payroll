require "rails_helper"

RSpec.describe NscSynchronizationJob do
  describe "#perform" do
    let(:identity) do
      create(
        :identity,
        first_name: first_name,
        last_name: last_name,
        date_of_birth: date_of_birth
      )
    end
    let(:activity_flow) do
      create(
        :activity_flow,
        identity: identity,
        education_activities_count: 0
      )
    end
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

    before do
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
    end

    context "when internal env and identity matches a fake scenario" do
      let(:first_name) { "Casey" }
      let(:last_name) { "Testuser" }
      let(:date_of_birth) { Date.parse("1991-04-22") }

      it "uses the demo fake data fetcher service" do
        allow(Rails.application.config).to receive(:is_internal_environment).and_return(true)
        fake_service = instance_double(DemoLauncher::FakeNscDataFetcherService, fetch: true)

        expect(DemoLauncher::FakeNscDataFetcherService)
          .to receive(:new)
          .with(education_activity: education_activity)
          .and_return(fake_service)
        expect(DemoLauncher::NscForwardDatingService).not_to receive(:applicable?)
        expect(DemoLauncher::NscForwardDatingService).not_to receive(:new)
        expect(NscDataFetcherService).not_to receive(:new)

        described_class.perform_now(education_activity.id)
      end
    end

    context "when internal env and invitation matches an NSC demo test user" do
      let(:first_name) { "Lynette" }
      let(:last_name) { "Oyola" }
      let(:date_of_birth) { Date.parse("1988-10-24") }
      let(:invitation) { create(:activity_flow_invitation, reference_id: "demo-lynette") }
      let(:activity_flow) do
        create(
          :activity_flow,
          identity: identity,
          activity_flow_invitation: invitation,
          education_activities_count: 0
        )
      end

      it "uses the demo NSC forward-dating service" do
        allow(Rails.application.config).to receive(:is_internal_environment).and_return(true)
        forward_dating_service = instance_double(DemoLauncher::NscForwardDatingService, fetch: true)

        expect(DemoLauncher::NscForwardDatingService)
          .to receive(:applicable?)
          .with(education_activity)
          .and_return(true)
        expect(DemoLauncher::NscForwardDatingService)
          .to receive(:new)
          .with(education_activity: education_activity)
          .and_return(forward_dating_service)
        expect(DemoLauncher::FakeNscDataFetcherService).not_to receive(:new)
        expect(NscDataFetcherService).not_to receive(:new)

        described_class.perform_now(education_activity.id)
      end
    end

    context "when not internal env" do
      let(:first_name) { "Casey" }
      let(:last_name) { "Testuser" }
      let(:date_of_birth) { Date.parse("1991-04-22") }

      it "uses the regular NSC data fetcher service" do
        allow(Rails.application.config).to receive(:is_internal_environment).and_return(false)
        nsc_service = instance_double(NscDataFetcherService, fetch: true)

        expect(DemoLauncher::NscForwardDatingService).not_to receive(:applicable?)
        expect(NscDataFetcherService)
          .to receive(:new)
          .with(education_activity: education_activity)
          .and_return(nsc_service)
        expect(DemoLauncher::FakeNscDataFetcherService).not_to receive(:new)
        expect(DemoLauncher::NscForwardDatingService).not_to receive(:new)

        described_class.perform_now(education_activity.id)
      end
    end
  end
end
