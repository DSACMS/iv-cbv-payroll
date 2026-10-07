require "rails_helper"

RSpec.describe ActivityFlowNavigator do
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
  end
end
