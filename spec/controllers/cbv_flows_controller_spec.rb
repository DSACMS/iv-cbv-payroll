require "rails_helper"

RSpec.describe CbvFlowsController do
  include ArgyleApiHelper
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

    let(:argyle_user_id) { "abc-def-ghi" }

    let(:user_token) { "foobar" }

    let(:argyle_mock_items_response) do
      {
        results: [
          {
            id: 'item_000002102',
            name: 'ACME'
          }
        ]
      }
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_items_response
      stub_create_user_response(user_id: argyle_user_id)
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
        expect(response).to be_ok
      end

      it "saves the token in the CbvFlow model" do
        expect { get :employer_search }
          .to change { cbv_flow.reload.argyle_user_id }
          .from(nil)
          .to(argyle_user_id)
      end
    end

    context "when the user already has an Argyle token in their session" do
      before do
        session[:argyle_user_token] = user_token
      end

      it "does not request a new User Token from Argyle" do
        get :employer_search
        expect(response).to be_ok
      end
    end
  end

  describe "#summary" do
    render_views

    let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", argyle_user_id: "abc-def-ghi") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_paystubs_response
    end

    it "renders properly" do
      get :summary
      expect(response).to be_successful
    end
  end
end
