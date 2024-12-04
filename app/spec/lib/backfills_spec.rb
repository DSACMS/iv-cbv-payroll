require "rails_helper"
require "rake"

RSpec.describe "backfills.rake" do
  describe "backfills:cbv_clients" do
    before(:all) do
      Rails.application.load_tasks
    end

    context "when there are backfills" do
      let(:cbv_flow_invitation) { create(:cbv_flow_invitation) }

      it "Back-fills cbv_clients from existing cbv data" do
        expect(cbv_flow_invitation.cbv_client).to be_nil
        Rake::Task['backfills:cbv_clients'].execute
        cbv_flow_invitation.reload
        expect(cbv_flow_invitation.cbv_client).to be_present
      end
    end
  end
end
