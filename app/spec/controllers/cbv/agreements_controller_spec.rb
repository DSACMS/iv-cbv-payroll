require "rails_helper"

RSpec.describe Cbv::AgreementsController do
  render_views
  it "renders properly" do
    get :show

    expect(response).to be_successful
  end

  it "displays error when the checkbox is not checked" do
    post :create, params: {}
    expect(flash[:alert]).to be_present
    expect(response).to redirect_to(cbv_flow_agreement_path)
  end

  it "redirects when checkbox is checked" do
    post :create, params: { 'agreement': '1' }
    expect(response).to redirect_to(cbv_flow_employer_search_path)
  end
end
