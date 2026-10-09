require "rails_helper"

RSpec.describe Activities::Income::SynchronizationsController do
  include_context "activity_hub"
  render_views

  let(:flow) { create(:activity_flow) }
  let(:errored_jobs) { [] }
  let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, with_errored_jobs: errored_jobs, flow: flow) }

  before do
    session[:flow_id] = flow.id
    session[:flow_type] = :activity
  end

  describe "#show" do
    let(:applicant) { create(:cbv_applicant, first_name: "Lisa", last_name: "Williams") }
    let(:invitation) { create(:activity_flow_invitation, cbv_applicant: applicant) }
    let(:flow) { create(:activity_flow, cbv_applicant: applicant, activity_flow_invitation: invitation) }

    before do
      allow_any_instance_of(PayrollAccount::Pinwheel).to receive(:has_fully_synced?).and_return(false)
      get :show, params: { user: { account_id: payroll_account.aggregator_account_id } }
    end

    it "does not display the reporting banner for a named applicant in a tokenized flow" do
      expect(response).to have_http_status(:ok)
      expect(Capybara.string(response.body)).to have_no_text("Reporting for")
    end
  end

  describe "#update" do
    context "when account exists but is not fully synced" do
      before do
        allow_any_instance_of(PayrollAccount::Pinwheel).to receive(:has_fully_synced?).and_return(false)
      end

      it "renders the page" do
        patch :update, params: { user: { account_id: payroll_account.aggregator_account_id } }

        expect(response.body).to include("turbo-frame id=\"synchronization\"")
      end

      it "does not render the activity flow header" do
        patch :update, params: { user: { account_id: payroll_account.aggregator_account_id } }

        expect(response.body).not_to include("exit-confirmation-modal")
      end
    end
  end
end
