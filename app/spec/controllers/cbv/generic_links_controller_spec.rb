require "rails_helper"

RSpec.describe Cbv::GenericLinksController do
  describe '#show' do
    context 'when the hostname matches a client agency domain and the pilot is active' do
      before do
        get :show, params: { client_agency_id: "sandbox" }
      end

      it "starts a CBV flow" do
        expect(response).to redirect_to(cbv_flow_entry_path)
        expect(assigns(:cbv_flow).client_agency_id).to eq("sandbox")
      end

      it "sets an encrypted permanent cookie with cbv_applicant_id" do
        cbv_flow = assigns(:cbv_flow)

        expect(cookies.encrypted[:cbv_applicant_id]).to eq(cbv_flow.cbv_applicant_id)

        cookie_jar = response.cookies["cbv_applicant_id"]
        expect(cookie_jar).to be_present
      end
    end

    context 'when the hostname matches a client agency domain and the pilot is ended' do
      before do
        stub_client_agency_config_value("la_ldh", "pilot_ended", true)
      end

      it "redirects to the root path" do
        get :show, params: { client_agency_id: "la_ldh" }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
