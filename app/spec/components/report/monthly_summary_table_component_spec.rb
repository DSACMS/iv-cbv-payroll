require "rails_helper"

RSpec.describe Report::MonthlySummaryTableComponent, type: :component do
  include ArgyleApiHelper
  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
  let(:account_id) { "019571bc-2f60-3955-d972-dbadfe0913a8" }
  let(:cbv_flow) do
    create(:cbv_flow,
           :invited,
           created_at: current_time,
           cbv_applicant: cbv_applicant
    )
  end
  let(:argyle_service) { Aggregators::Sdk::ArgyleService.new("sandbox") }
  let!(:payroll_account) do
    create(
      :payroll_account,
      :argyle_fully_synced,
      cbv_flow: cbv_flow,
      pinwheel_account_id: account_id
      )
  end

  context "with argyle" do
    context "with bob, a gig-worker" do
      let(:argyle_report) { Aggregators::AggregatorReports::ArgyleReport.new(payroll_accounts: [ payroll_account ], argyle_service: argyle_service) }# , from_date: current_time, to_date: current_time) }
      before do
        # session[:cbv_flow_id] = cbv_flow.id
        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        Timecop.freeze(Time.local(2025, 04, 1, 0, 0))
        # allow(argyle_service).to receive(:fetch_account_api).and_return(argyle_load_relative_json_file("bob", "request_account.json"))
        # allow(argyle_service).to receive(:fetch_identities_api).and_return(argyle_load_relative_json_file("bob", "request_identity.json"))
        # allow(argyle_service).to receive(:fetch_paystubs_api).and_return(argyle_load_relative_json_file("bob", "request_paystubs.json"))
        argyle_report.fetch
      end

      it "argyle_report is properly fetched" do
        expect(argyle_report.gigs.length).to be(100)
      end

      xit "renders helllllo" do
        expect(
          render_inline(described_class.new)
        ).to have_text(
               "Helllllllo"
             )
      end

      describe "#summarize_by_month" do
        it "returns a hash of monthly totals" do
          summary_component = described_class.new(argyle_report, payroll_account)
          expect(summary_component.summarize_by_month).to eq({
            "2025-04" => {
              "gigs" => 100,
              "paystubs" => 100,
              "payroll_accounts" => 1,
              "total_payroll_accounts" => 1,
              "total_gigs" => 100,
              "total_paystubs" => 100
            }
          })
        end
      end
    end
  end
end
