require "rails_helper"

RSpec.describe Cbv::SuccessesController do
  include PinwheelApiHelper

  describe "#show" do
    let(:cbv_flow) { create(:cbv_flow, :invited, confirmation_code: "NYC12345") }
    let(:cbv_flow_without_invitation) { create(:cbv_flow, confirmation_code: "NYC12345") }
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
        expect(response.body).to have_selector('button[data-copy-link-target="copyLinkButton"]')
      end

      describe "#invitation_link" do
        context "in production environment" do
          before do
            stub_client_agency_config_value("sandbox", "agency_domain", "sandbox.reportmyincome.org")
          end

          it "uses agency production domain" do
            get :show

            expected_url = "https://sandbox.reportmyincome.org/en/cbv/entry?token=#{cbv_flow.cbv_flow_invitation.auth_token}"
            expect(response.body).to include(expected_url)
          end
        end

        context "in non-production environment" do
          before do
            stub_client_agency_config_value("sandbox", "agency_domain", "sandbox-verify-demo.navapbc.cloud")
          end

          it "uses agency demo domain" do
            get :show
            expected_url = "https://sandbox-verify-demo.navapbc.cloud/en/cbv/entry?token=#{cbv_flow.cbv_flow_invitation.auth_token}"
            expect(response.body).to include(expected_url)
          end
        end

        context "when the cbv_flow originates from a generic link" do
          before do
            session[:cbv_flow_id] = cbv_flow_without_invitation.id
            stub_client_agency_config_value("sandbox", "agency_domain", "sandbox-verify-demo.navapbc.cloud")
          end

          it "generates a generic link" do
            get :show

            expected_url = "https://sandbox-verify-demo.navapbc.cloud/en/cbv/links/sandbox"
            expect(response.body).to include(expected_url)
          end

          context "with missing host configuration" do
            before do
              session[:cbv_flow_id] = cbv_flow_without_invitation.id
              stub_client_agency_config_value("sandbox", "agency_domain", nil)
            end

            it "generates a generic link" do
              get :show

              expected_url = "http://localhost/en/cbv/links/sandbox"
              expect(response.body).to include(expected_url)
            end
          end
        end
      end
    end
  end
end
