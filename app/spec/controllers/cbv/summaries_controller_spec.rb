require "rails_helper"

RSpec.describe Cbv::SummariesController do
  include PinwheelApiHelper
  let(:cbv_flow_props) do  {
    first_name: "John",
    middle_name: "Doe",
    last_name: "Smith",
    case_number: "ABC1234",
    email_address: "tom@example.com",
    agency_id_number: "A12345",
    site_id: "sandbox",
    snap_application_date: Date.parse('2024-06-18'),
    created_at: Time.new(2024, 8, 1, 12, 0, 0, "-04:00"),
    id: 1
  }
  end
  let(:cbv_flow_invitation) { CbvFlowInvitation.create(cbv_flow_props) }
  let(:cbv_flow) { CbvFlow.create(case_number: "ABC1234", pinwheel_token_id: "abc-def-ghi", site_id: "sandbox", cbv_flow_invitation_id: 1) }

  before do
    session[:cbv_flow_invitation] = cbv_flow_invitation
    session[:cbv_flow] = cbv_flow
  end

  describe "#show" do
    before do
      session[:cbv_flow_id] = cbv_flow.id
      stub_request_end_user_accounts_response
      stub_request_end_user_paystubs_response
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(assigns[:already_consented]).to eq(false)
        # 90 days before snap_application_date
        start_date = "March 20, 2024"
        # Should be the formatted version of snap_application_date
        end_date = "June 18, 2024"
        expect(assigns[:summary_end_date]).to eq(end_date)
        expect(assigns[:summary_start_date]).to eq(start_date)
        expect(response.body).to include("Legal Agreement")
        expect(response).to be_successful
      end

      it "renders pdf properly" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end
    end

    context "when legal agreement checked" do
      before do
        cbv_flow.update(consented_to_authorized_use_at: Time.now)
      end

      it "hides legal agreement if already checked" do
        get :show

        expect(response.body).not_to include("Legal Agreement")
      end
    end

    context "for a completed CbvFlow" do
      let(:cbv_flow) do
        CbvFlow.create(
          case_number: "ABC1234",
          pinwheel_token_id: "abc-def-ghi",
          site_id: "sandbox",
          confirmation_code: "ABC1234",
          cbv_flow_invitation_id: 1
        )
      end
      it "allows the user to download the PDF summary" do
        get :show, format: :pdf
        expect(response).to be_successful
        expect(response.header['Content-Type']).to include 'pdf'
      end

      it "redirects the user to the success page if the user goes back to the page" do
        get :show
        expect(response).to redirect_to(cbv_flow_success_path)
      end
    end
  end
end
