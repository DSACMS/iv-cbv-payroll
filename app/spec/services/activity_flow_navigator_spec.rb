require "rails_helper"

RSpec.describe ActivityFlowNavigator do
  include Rails.application.routes.url_helpers

  it_behaves_like "a flow navigator"

  describe "#next_path" do
    it "returns the income synchronization path for the activity employer search controller" do
      navigator = described_class.new({ controller: "activities/income/employer_searches" })

      expect(navigator.next_path).to eq(navigator.income_sync_path(:synchronizations))
    end

    it "returns the payment details path for the activity synchronizations controller" do
      navigator = described_class.new({ controller: "activities/income/synchronizations" })

      expect(navigator.next_path).to eq(navigator.income_sync_path(:payment_details))
    end

    describe "after the activity payment details controller" do
      let(:params) { { controller: "activities/income/payment_details" } }

      it "returns the activity root path when the flow is employment-focused, regardless of routing requirements" do
        overall_progress_result = ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: true)
        navigator = described_class.new(params, overall_progress_result: overall_progress_result, employment_focused: true)

        expect(navigator.next_path).to eq(activities_flow_root_path)
      end

      it "returns the activity root path when there is no overall progress result" do
        navigator = described_class.new(params, employment_focused: false)

        expect(navigator.next_path).to eq(activities_flow_root_path)
      end

      it "returns the summary path when routing requirements are met" do
        overall_progress_result = ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: true)
        navigator = described_class.new(params, overall_progress_result: overall_progress_result, employment_focused: false)

        expect(navigator.next_path).to eq(activities_flow_summary_path)
      end

      it "returns the activity root path when routing requirements are not met" do
        overall_progress_result = ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: false)
        navigator = described_class.new(params, overall_progress_result: overall_progress_result, employment_focused: false)

        expect(navigator.next_path).to eq(activities_flow_root_path)
      end
    end
  end
end
