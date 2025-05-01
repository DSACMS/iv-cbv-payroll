require "rails_helper"

RSpec.describe Cbv::GenericLinksController do
  describe '#show' do
    context 'when the hostname matches a client agency domain' do
      it "starts a CBV flow" do
        request.host = "sandbox.reportmyincome.org"
        get :show, params: { client_agency_id: "sandbox" }
        expect(response).to redirect_to(cbv_flow_entry_path)
        expect(assigns(:cbv_flow).client_agency_id).to eq("sandbox")
      end
    end
  end
end
