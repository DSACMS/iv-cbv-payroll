require "rails_helper"

RSpec.describe Cbv::ApplicantInformationsController, type: :controller do
  describe "#show" do
    let(:cbv_flow) do
      create(:cbv_flow)
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    context "when the user is uninvited" do
      let(:cbv_flow) { create(:cbv_flow) }
      render_views

      it "renders the sandbox fields" do
        get :show

        expect(response.body).to include("first_name")
        expect(response.body).to include("middle_name")
        expect(response.body).to include("last_name")
        expect(response.body).to include("date_of_birth")
        expect(response.body).to include("case_number")
      end

      it "stays on the same page and shows the right errors when required fields are missing" do
        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Tim", # required
              middle_name: "",
              last_name: "", # required
              date_of_birth: "", # required
              case_number: "" # required
            }
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.first_name.blank"))
        expect(response.body).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.middle_name.blank"))
        expect(response.body).to include(I18n.t("cbv.applicant_informations.sandbox.fields.last_name.blank"))
        expect(response.body).to include(I18n.t("cbv.applicant_informations.sandbox.fields.date_of_birth.blank"))
        expect(response.body).to include(I18n.t("cbv.applicant_informations.sandbox.fields.case_number.blank"))
      end

      it "redirects to summary when fields are satisfied" do
        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Tim", # required
              middle_name: "",
              last_name: "Miller", # required
              date_of_birth: "01/01/1980", # required
              case_number: "9971" # required
            }
          }
        }

        expect(response).to redirect_to(cbv_flow_summary_path)
      end

      it "stays on the page if fields are satisfied and the force_show parameter is present" do
        get :show, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Tim", # required
              middle_name: "",
              last_name: "Miller", # required
              date_of_birth: "01/01/1980", # required
              case_number: "9971" # required
            }
          },
          force_show: true
        }

        expect(response.body).to include("first_name")
        expect(response.body).to include("middle_name")
        expect(response.body).to include("last_name")
        expect(response.body).to include("case_number")
      end
    end

    context "when the user is invited" do
      let(:cbv_flow) { create(:cbv_flow, :invited) }
      render_views

      it "redirects to the summary" do
        get :show

        expect(response).to redirect_to(cbv_flow_summary_path)
      end
    end
  end
end
