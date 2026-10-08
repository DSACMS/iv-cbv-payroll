require "rails_helper"

RSpec.describe ActivityFlowNavigator do
  it_behaves_like "a flow navigator"

  describe "#next_path" do
    describe "employment completion" do
      subject(:navigator) do
        described_class.new({ controller: "activities/employment" }, flow, overall_progress_result: progress)
      end

      let(:flow) { build_stubbed(:activity_flow) }
      let(:progress) { ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: false) }

      it "returns to the hub when more verified activity is needed" do
        expect(navigator.next_path).to eq(navigator.activities_flow_root_path)
      end

      context "with sufficient verified activity" do
        let(:progress) { ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: true) }

        it "continues to the summary" do
          expect(navigator.next_path).to eq(navigator.activities_flow_summary_path)
        end
      end

      context "with unpaid-only employment" do
        let(:flow) { build_stubbed(:activity_flow, unpaid_work_only: true) }

        it "returns to the hub without work selection" do
          expect(navigator.next_path).to eq(navigator.activities_flow_root_path)
        end
      end

      context "with employment-focused reporting" do
        let(:flow) { build_stubbed(:activity_flow, employment_focused: true) }

        it "asks whether there are more jobs" do
          expect(navigator.next_path).to eq(navigator.activities_flow_income_add_jobs_path)
        end
      end
    end

    it "returns the income synchronization path for the activity employer search controller" do
      navigator = described_class.new({ controller: "activities/income/employer_searches" })

      expect(navigator.next_path).to eq(navigator.income_sync_path(:synchronizations))
    end

    it "returns the payment details path for the activity synchronizations controller" do
      navigator = described_class.new({ controller: "activities/income/synchronizations" })

      expect(navigator.next_path).to eq(navigator.income_sync_path(:payment_details))
    end
  end
end
