require "rails_helper"

RSpec.describe NscDataFetcherService do
  include NscApiHelper

  subject(:service) { described_class.new(education_activity: education_activity, environment: :test, logger: logger) }

  let(:activity_flow) { create(:activity_flow, identity: identity, education_activities_count: 0) }
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }
  let(:logger) { Logger.new(StringIO.new) }

  before do
    stub_const("Aggregators::Sdk::NscService::ENVIRONMENTS", {
      test: {
        base_url: "http://fake-nsc-api.local",
        token_url: "http://fake-nsc-api.local/token",
        client_id: "123",
        client_secret: "top-secret",
        account_id: "456",
        scope: "vs.api.insights"
      }
    })
  end

  describe "#fetch" do
    before do
      nsc_stub_token_request
    end

    context "when there are no enrollments (Linda)" do
      let(:identity) { create(:identity, :nsc_linda) }

      before do
        nsc_stub_request_education_search_response("linda")
      end

      it "updates the EducationActivity to have sync status = :no_enrollments" do
        expect { service.fetch }
          .to change { education_activity.reload.dup } # rubocop:disable RSpec/ExpectChange
          .from(have_attributes(status: "unknown", enrollment_status: "unknown"))
          .to(have_attributes(status: "no_enrollments", enrollment_status: "unknown"))
      end
    end

    context "when there is one enrollment" do
      let(:identity) { create(:identity, :nsc_lynette) }

      before do
        nsc_stub_request_education_search_response("lynette")
      end

      it "returns an EducationActivity with sync status = :succeeded" do
        expect { service.fetch }
          .to change { education_activity.reload.dup } # rubocop:disable RSpec/ExpectChange
          .from(have_attributes(status: "unknown", enrollment_status: "unknown"))
          .to(have_attributes(
            status: "succeeded",
            enrollment_status: "enrolled",
            school_name: "Trident University International"
          ))
      end
    end

    context "when there are multiple enrollments" do
      let(:identity) { create(:identity, :nsc_rick) }

      before do
        nsc_stub_request_education_search_response("rick_banas")
      end

      it "returns an EducationActivity with sync status = :succeeded" do
        expect { service.fetch }
          .to change { education_activity.reload.dup } # rubocop:disable RSpec/ExpectChange
          .from(have_attributes(status: "unknown", enrollment_status: "unknown"))
          .to(have_attributes(
            status: "succeeded",
            enrollment_status: "half_time",
            school_name: "FLORIDA A&M UNIVERSITY"
          ))
      end
    end
  end
end
