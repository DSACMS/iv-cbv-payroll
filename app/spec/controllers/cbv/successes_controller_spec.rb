require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow, :invited, confirmation_code: "NYC12345") }
    let(:agency_config) { Rails.application.config.client_agencies["sandbox"] }

    before do
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_end_user_accounts_response
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when rendering views" do
      render_views

      it "renders properly" do
        get :show
        expect(response).to be_successful
      end

      it "shows confirmation code in view" do
        get :show
        expect(response.body).to include(cbv_flow.confirmation_code)
      end

      it "shows copy link button" do
        get :show
        expect(response.body).to include(I18n.t("cbv.successes.show.copy_link"))
        expect(response.body).to have_selector('button[data-controller="copy-link"]')
      end

      describe "invitation_link" do
        let(:cbv_flow_with_invitation) { create(:cbv_flow, :invited) }

        context "in production environment" do
          before do
            session[:cbv_flow_id] = cbv_flow_with_invitation.id
          end

          it "uses agency production domain" do
            allow(Rails.env).to receive(:production?).and_return(true)
            get :show

            expected_url = "https://sandbox.reportmyincome.org/en/cbv/entry?token=#{cbv_flow_with_invitation.cbv_flow_invitation.auth_token}"
            expect(response.body).to include(expected_url)
          end
        end

        context "in non-production environment" do
          before do
            session[:cbv_flow_id] = cbv_flow_with_invitation.id
          end

          it "uses agency demo domain" do
            allow(Rails.env).to receive(:production?).and_return(false)
            get :show

            expected_url = "https://sandbox-verify-demo.navapbc.cloud/en/cbv/entry?token=#{cbv_flow_with_invitation.cbv_flow_invitation.auth_token}"
            expect(response.body).to include(expected_url)
          end
        end
      end
    end
  end
end
