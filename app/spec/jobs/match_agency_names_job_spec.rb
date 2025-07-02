require "rails_helper"

RSpec.describe MatchAgencyNamesJob do
  include ArgyleApiHelper

  let(:cbv_flow) { create(:cbv_flow, :with_argyle_account) }

  before do
    argyle_stub_request_identities_response("bob")
    argyle_stub_request_accounts_response("bob")
    argyle_stub_request_paystubs_response("bob")
    argyle_stub_request_gigs_response("bob")

    allow_any_instance_of(GenericEventTracker)
      .to receive(:track)
  end

  subject { described_class.perform_now(cbv_flow.id) }

  context "when there are no agency expected names" do
    it "does not track any event" do
      expect_any_instance_of(GenericEventTracker)
        .not_to receive(:track)

      subject
    end
  end

  context "when there are agency expected names" do
    let(:cbv_applicant) { create(:cbv_applicant, :az_des) }
    let(:cbv_flow) { create(:cbv_flow, :with_argyle_account, cbv_applicant: cbv_applicant) }

    it "tracks an event with the name match results" do
      expect_any_instance_of(GenericEventTracker)
        .to receive(:track)
        .with("IncomeSummaryMatchedAgencyNames", nil, include(
          cbv_flow_id: cbv_flow.id,
          total_report_names_count: 1,
          total_agency_names_count: 1,
          exact_match_count: 0,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 1,
        ))

      subject
    end
  end
end
