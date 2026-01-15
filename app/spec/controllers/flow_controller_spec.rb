require "rails_helper"

RSpec.describe FlowController do
  describe "#flow_navigator" do
    before do
      allow(controller.request)
        .to receive(:path)
        .and_return(path)
    end

    context "for a page within the CBV flow" do
      let(:path) { "/cbv/entries" }

      it "returns the CbvFlowNavigator" do
        expect(controller.flow_navigator)
          .to be_a(CbvFlowNavigator)
      end

      context "when there is a locale prefix in the URL" do
        let(:path) { "/en/cbv/entries" }

        it "returns the CbvFlowNavigator" do
          expect(controller.flow_navigator)
            .to be_a(CbvFlowNavigator)
        end
      end
    end

    context "for a page within the Activity flow" do
      let(:path) { "/activities" }

      it "returns the ActivityFlowNavigator" do
        expect(controller.flow_navigator)
          .to be_a(ActivityFlowNavigator)
      end

      context "when there is a locale prefix in the URL" do
        let(:path) { "/en/activities" }

        it "returns the ActivityFlowNavigator" do
          expect(controller.flow_navigator)
            .to be_a(ActivityFlowNavigator)
        end
      end
    end
  end
end
