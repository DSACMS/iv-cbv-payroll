require "rails_helper"

RSpec.describe Activities::Income::PayrollConsentsController do
  include_context "activity_hub"

  let(:flow) { create(:activity_flow) }

  before do
    session[:flow_id] = flow.id
    session[:flow_type] = :activity
  end

  it "reports missing consent without recording it" do
    get :show, format: :json
    expect(response.parsed_body).to eq("consented" => false)
    expect(flow.reload.payroll_consented_at).to be_nil
  end

  it "records explicit consent for the current flow" do
    post :create, params: { consent: "1" }, format: :json
    expect(response.parsed_body).to eq("consented" => true)
    expect(flow.reload.payroll_consented_at).to be_present
  end

  it "rejects a request without consent" do
    post :create, format: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(flow.reload.payroll_consented_at).to be_nil
  end

  context "after consenting" do
    let(:consented_at) { 1.hour.ago.change(usec: 0) }

    before { flow.update!(payroll_consented_at: consented_at) }

    it "reports consent when returning to search" do
      get :show, format: :json
      expect(response.parsed_body).to eq("consented" => true)
    end

    it "preserves the first consent timestamp on repeated requests" do
      post :create, params: { consent: "1" }, format: :json
      expect(flow.reload.payroll_consented_at).to eq(consented_at)
    end
  end

  context "in another flow" do
    before { create(:activity_flow, payroll_consented_at: Time.current) }

    it "does not reuse consent from a different flow" do
      get :show, format: :json
      expect(response.parsed_body).to eq("consented" => false)
    end
  end

  context "without an active session" do
    before { session.clear }

    it "does not record consent" do
      post :create, params: { consent: "1" }, format: :json
      expect(response).to have_http_status(:redirect)
      expect(flow.reload.payroll_consented_at).to be_nil
    end
  end

  context "after completing the flow" do
    before { flow.update!(completed_at: Time.current) }

    it "redirects instead of recording consent" do
      post :create, params: { consent: "1" }, format: :json
      expect(response).to redirect_to(activities_flow_success_path)
      expect(flow.reload.payroll_consented_at).to be_nil
    end
  end
end
