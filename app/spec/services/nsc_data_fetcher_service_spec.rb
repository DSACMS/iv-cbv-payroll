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
          .from(have_attributes(status: "unknown"))
          .to(have_attributes(status: "no_enrollments"))
      end

      it "does not create any NscEnrollmentTerm's" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms)
          .to be_empty
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
          .from(have_attributes(status: "unknown"))
          .to(have_attributes(status: "succeeded"))
      end

      it "saves the enrollment details into an NscEnrollmentTerm" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms.first)
          .to have_attributes(
            school_name: "Trident University International",
            enrollment_status: "enrolled", # Y
            term_begin: Date.parse("2024-05-31"),
            term_end: Date.parse("2024-11-19"),
          )
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
          .from(have_attributes(status: "unknown"))
          .to(have_attributes(status: "succeeded"))
      end

      it "saves the enrollment details into multiple NscEnrollmentTerm's" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms.first)
          .to have_attributes(
            school_name: "FLORIDA A&M UNIVERSITY",
            enrollment_status: "half_time",
            term_begin: Date.parse("2024-06-19"),
            term_end: Date.parse("2024-11-29"),
          )
        expect(education_activity.nsc_enrollment_terms.second)
          .to have_attributes(
            school_name: "FLORIDA STATE UNIVERSITY",
            enrollment_status: "half_time",
            term_begin: Date.parse("2024-05-31"),
            term_end: Date.parse("2024-11-29"),
          )
      end
    end
  end
end
