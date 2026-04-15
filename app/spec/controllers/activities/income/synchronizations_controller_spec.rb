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
