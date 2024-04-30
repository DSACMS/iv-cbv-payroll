require "rails_helper"

RSpec.describe CbvFlowsController do
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  around do |ex|
    stub_environment_variable("ARGYLE_API_TOKEN", "foobar", &ex)
  end

  describe "#entry" do
    render_views

    it "renders properly" do
      get :entry

      expect(response).to be_successful
    end

    it "sets a CbvFlow object in the session" do
      expect { get :entry }
        .to change { session[:cbv_flow_id] }
        .from(nil)
        .to(be_an(Integer))
    end
  end

  describe "#employer_search" do
    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234") }
    let(:argyle_mock_response) do
      {
        id: "abc-def-ghi",
        user_token: "foobar"
      }
    end

    let(:argyle_mock_items_response) do
      {
        results: [
          {
            id: 'item_000002102',
            name: 'ACME',
          },
        ]
      }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id

      allow(Net::HTTP).to receive(:post)
        .with(URI(CbvFlowsController::USER_TOKEN_ENDPOINT), anything, anything)
        .and_return(instance_double(Net::HTTPOK, code: "200", body: JSON.generate(argyle_mock_response)))

      allow(Net::HTTP).to receive(:get)
        .with(URI(CbvFlowsController::ITEMS_ENDPOINT), anything)
        .and_return(JSON.generate(argyle_mock_items_response))
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :employer_search
        expect(response).to be_successful
      end
    end

    context "when the user does not have an Argyle token" do
      it "requests a new token from Argyle" do
        get :employer_search
        expect(Net::HTTP).to have_received(:post).once
      end

      it "saves the token in the CbvFlow model" do
        expect { get :employer_search }
          .to change { cbv_flow.reload.argyle_user_id }
          .from(nil)
          .to(argyle_mock_response[:id])
      end
    end

    context "when the user already has an Argyle token in their session" do
      before do
        session[:argyle_user_token] = argyle_mock_response[:user_token]
      end

      it "does not request a new User Token from Argyle" do
        get :employer_search
        expect(Net::HTTP).not_to have_received(:post)
      end
    end
  end

  describe "#summary" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi") }
    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    it "renders properly" do
      get :summary
      expect(response).to be_successful
    end
  end
end
