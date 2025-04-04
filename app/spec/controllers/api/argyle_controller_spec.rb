require 'rails_helper'

RSpec.describe Api::ArgyleController, type: :controller do
  describe "POST #create" do
    it "includes isSandbox flag in response" do
      cbv_flow = double('cbv_flow', client_agency_id: 'test_agency')
      argyle = double('argyle', create_user: {})

      allow(CbvFlow).to receive(:find).and_return(cbv_flow)
      allow(controller).to receive(:argyle_for).and_return(argyle)
      allow(controller).to receive(:agency_config).and_return({
        'test_agency' => double(argyle_environment: 'sandbox')
      })

      post :create

      expect(JSON.parse(response.body)["isSandbox"]).to eq(true)
    end
  end
end
