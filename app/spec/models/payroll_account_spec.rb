require "rails_helper"

RSpec.describe PayrollAccount do
  let(:flow) { create(:activity_flow) }

  describe ".published" do
    it "returns only non-draft records" do
      published = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: false)
      _draft = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: true)

      expect(flow.payroll_accounts.published).to contain_exactly(published)
    end
  end

  describe "#publish!" do
    it "sets draft to false" do
      account = create(:payroll_account, :pinwheel_fully_synced, flow: flow, draft: true)

      account.publish!

      expect(account.reload.draft).to be(false)
    end
  end
end
