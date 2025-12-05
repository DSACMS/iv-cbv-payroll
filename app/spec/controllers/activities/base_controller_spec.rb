require 'rails_helper'

RSpec.describe Activities::BaseController, type: :controller do
  let(:activity_flow) { create(:activity_flow) }

  controller(described_class) do
    def show
      render plain: "hello world"
    end
  end

  before do
    routes.draw do
      get 'show', controller: "activities/base"
    end
  end

  describe '#set_activity_flow' do
    it "sets the activity flow in the session" do
      session[:flow_id] = activity_flow.id
      expect {
        get :show
      }.not_to change(ActivityFlow, :count)

      expect(session[:flow_type]).to eq(:activity)
    end

    context "when no session is present" do
      it "creates a new activity flow and sets it in the session" do
        expect {
          get :show
        }.to change(ActivityFlow, :count).by(1)

        expect(session[:flow_id]).to be_present
      end
    end
  end
end
