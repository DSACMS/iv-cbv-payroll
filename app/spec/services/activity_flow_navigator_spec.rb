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

      context "when employment-focused" do
        let(:overall_progress_result) { ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: true) }
        let(:navigator) { described_class.new(params, overall_progress_result: overall_progress_result, employment_focused: true) }

        it "returns the add jobs path when routing requirements are met" do
          expect(navigator.next_path).to eq(activities_flow_income_add_jobs_path)
        end

        context "when routing requirements are not met" do
          let(:overall_progress_result) { ActivityFlowProgressCalculator::OverallResult.new(meets_routing_requirements: false) }

          it "returns the add jobs path" do
            expect(navigator.next_path).to eq(activities_flow_income_add_jobs_path)
          end
        end

        context "when there is no overall progress result" do
          let(:overall_progress_result) { nil }

          it "returns the add jobs path" do
            expect(navigator.next_path).to eq(activities_flow_income_add_jobs_path)
          end
        end

        context "when the employment-focused state is provided by the flow" do
          let(:flow) { instance_double(ActivityFlow, employment_focused?: true) }
          let(:navigator) { described_class.new(
            params,
            flow,
            overall_progress_result: overall_progress_result,
            employment_focused: flow.employment_focused?) }

          it "returns the add jobs path" do
            expect(navigator.next_path).to eq(activities_flow_income_add_jobs_path)
          end
        end

        context "when using the CBV payment details controller" do
          let(:params) { { controller: "cbv/payment_details" } }

          it "returns the add jobs path" do
            expect(navigator.next_path).to eq(activities_flow_income_add_jobs_path)
          end
        end
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
