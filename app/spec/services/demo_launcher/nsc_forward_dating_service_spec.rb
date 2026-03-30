require "rails_helper"

RSpec.describe DemoLauncher::NscForwardDatingService do
  include NscApiHelper

  subject(:service) { described_class.new(education_activity: education_activity, environment: :test, logger: logger) }

  let(:logger) { Logger.new(StringIO.new) }
  let(:identity) do
    create(
      :identity,
      first_name: first_name,
      last_name: last_name,
      date_of_birth: date_of_birth
    )
  end
  let(:invitation) { create(:activity_flow_invitation, reference_id: "demo-#{scenario_key}") }
  let(:activity_flow) do
    create(
      :activity_flow,
      identity: identity,
      activity_flow_invitation: invitation,
      education_activities_count: 0
    )
  end
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }

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
    nsc_stub_token_request
  end

  describe "#fetch" do
    context "for Lynette" do
      let(:scenario_key) { "lynette" }
      let(:first_name) { "Lynette" }
      let(:last_name) { "Oyola" }
      let(:date_of_birth) { Date.parse("1988-10-24") }

      before do
        nsc_stub_request_education_search_response("lynette")
      end

      it "forward-dates the returned term into the reporting window" do
        service.fetch

        term = education_activity.nsc_enrollment_terms.first
        delta_days = (activity_flow.reporting_window_range.max - Date.parse("2024-11-19")).to_i
        expect(term.term_begin).to eq(Date.parse("2024-05-31") + delta_days)
        expect(term.term_end).to eq(activity_flow.reporting_window_range.max)
        expect(activity_flow.within_reporting_window?(term.term_begin, term.term_end)).to be(true)
      end
    end

    context "for Rick" do
      let(:scenario_key) { "rick" }
      let(:first_name) { "Rick" }
      let(:last_name) { "Banas" }
      let(:date_of_birth) { Date.parse("1979-08-18") }

      before do
        nsc_stub_request_education_search_response("rick_banas")
      end

      it "forward-dates both returned terms while preserving their spacing" do
        service.fetch

        terms = education_activity.nsc_enrollment_terms.order(:term_begin)
        delta_days = (activity_flow.reporting_window_range.max - Date.parse("2024-11-29")).to_i

        expect(terms.count).to eq(2)
        expect(terms.map(&:term_begin)).to eq([ Date.parse("2024-05-31") + delta_days, Date.parse("2024-06-19") + delta_days ])
        expect(terms.map(&:term_end)).to eq([ activity_flow.reporting_window_range.max, activity_flow.reporting_window_range.max ])
        expect((terms.last.term_begin - terms.first.term_begin).to_i).to eq(19)
        expect(terms).to all(satisfy { |term| activity_flow.within_reporting_window?(term.term_begin, term.term_end) })
      end
    end

    context "for a demo user with no current enrollments" do
      let(:scenario_key) { "linda" }
      let(:first_name) { "Linda" }
      let(:last_name) { "Cooper" }
      let(:date_of_birth) { Date.parse("1999-01-01") }

      before do
        nsc_stub_request_education_search_response("linda")
      end

      it "preserves the no-enrollments result" do
        expect { service.fetch }
          .to change { education_activity.reload.status }
          .from("unknown").to("no_enrollments")

        expect(education_activity.nsc_enrollment_terms).to be_empty
      end
    end
  end
end
