require "rails_helper"

RSpec.describe BackfillAdditionalInformationService, type: :service do
  describe ".perform" do
    it "copies cbv_flow additional_information into payroll_account additional_information" do
      cbv_flow = create(:cbv_flow)
      payroll_account = create(:payroll_account, flow: cbv_flow, aggregator_account_id: "cbv-123")
      cbv_flow.update!(additional_information: { "cbv-123" => { "comment" => "cbv note" } })

      described_class.perform

      expect(payroll_account.reload.additional_information).to eq("cbv note")
    end

    it "copies activity_flow additional_information into payroll_account additional_information" do
      activity_flow = create(:activity_flow)
      payroll_account = create(
        :payroll_account,
        flow: activity_flow,
        aggregator_account_id: "activity-123"
      )
      activity_flow.update!(additional_information: { "activity-123" => { "comment" => "activity note" } })

      described_class.perform

      expect(payroll_account.reload.additional_information).to eq("activity note")
    end

    it "does not crash when a cbv_flow has no payroll accounts" do
      cbv_flow = create(:cbv_flow)
      cbv_flow.update!(additional_information: { "missing-1" => { "comment" => "note" } })

      expect { described_class.perform }.not_to raise_error
    end

    it "does not crash when the cbv_flow payroll account is missing" do
      cbv_flow = create(:cbv_flow)
      payroll_account = create(:payroll_account, flow: cbv_flow, aggregator_account_id: "real-1")
      cbv_flow.update!(additional_information: { "missing-1" => { "comment" => "note" } })

      expect { described_class.perform }.not_to raise_error
      expect(payroll_account.reload.additional_information).to be_nil
    end
  end
end
