RSpec.shared_examples_for "a flow navigator" do
  let(:params) { { controller: "test" } }
  subject(:navigator) { described_class.new(params) }

  it "has a next_path method" do
    navigator = described_class.new(params)
    expect(navigator).to respond_to(:next_path)
  end

  describe "#income_sync_path" do
    it "returns a value for :synchronizations" do
      expect(navigator.income_sync_path(:synchronizations, user: { account_id: "abc" }))
        .to be_present
    end

    it "returns a value for :payment_details" do
      expect(navigator.income_sync_path(:payment_details, user: { account_id: "abc" }))
        .to be_present
    end

    it "returns a value for :synchronization_failures" do
      expect(navigator.income_sync_path(:synchronization_failures))
        .to be_present
    end
  end
end
