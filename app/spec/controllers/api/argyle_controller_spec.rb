require 'rails_helper'

RSpec.describe Api::ArgyleController, type: :controller do
  describe "POST #create" do
    it "includes isSandbox flag in response" do
      allow(ENV).to receive(:[]).and_return(nil)
      allow(ENV).to receive(:[]).with("ARGYLE_SANDBOX").and_return("true")
      allow(CbvFlow).to receive(:find).and_return(double)
      allow(controller).to receive(:argyle_for).and_return(double(create_user: {}))

      post :create

      expect(JSON.parse(response.body)["isSandbox"]).to eq(true)
    end
  end
end
