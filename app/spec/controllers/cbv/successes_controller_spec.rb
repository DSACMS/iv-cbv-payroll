require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  describe "#show" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      context "when confirmation_number is blank" do
        it "generates a new confirmation number" do
          expect(cbv_flow.confirmation_number).to be_blank
          get :show
          expect(cbv_flow.reload.confirmation_number).not_to be_blank
          expect(response.body).to include(cbv_flow.confirmation_number)
        end

        it "generates a new confirmation number with a prefix" do
          expect(cbv_flow.confirmation_number).to be_blank
          session[:state] = "ny"
          get :show
          expect(cbv_flow.reload.confirmation_number).to start_with("ny-")
          expect(response.body).to include(cbv_flow.confirmation_number)
        end
      end

      context "when confirmation_number already exists" do
        let(:existing_confirmation_number) { "123456" }

        before do
          cbv_flow.update(confirmation_number: existing_confirmation_number)
        end

        it "does not override the existing confirmation number" do
          expect(cbv_flow.reload.confirmation_number).to eq(existing_confirmation_number)
          get :show
          expect(response.body).to include(existing_confirmation_number)
        end
      end
    end
  end
end
