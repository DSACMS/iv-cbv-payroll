require "rails_helper"

RSpec.describe Cbv::GenericLinksController, type: :controller do
  let(:la_ldh_agency_id) { "la_ldh" }
  let(:other_valid_agency_id) { "az_des" }

  describe "GET #show" do
    it "redirects la_ldh agency to cbv_flow_entry_path" do
      # expect next_path to not be called for la_ldh
      expect(controller).not_to receive(:next_path)
      get :show, params: { client_agency_id: la_ldh_agency_id }
      expect(response).to redirect_to(cbv_flow_entry_path)
    end

    it "redirects other valid agencies to next_path" do
      expect(controller).to receive(:next_path)
      get :show, params: { client_agency_id: other_valid_agency_id }
      expect(response).to redirect_to(cbv_flow_entry_path)
    end
  end
end
