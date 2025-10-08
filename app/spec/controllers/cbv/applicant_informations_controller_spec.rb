require "rails_helper"

RSpec.describe Cbv::ApplicantInformationsController, type: :controller do
  include ActiveSupport::Testing::TimeHelpers
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
        aggregate_failures do
          expect(response.body).to include("first_name")
          expect(response.body).to include("middle_name")
          expect(response.body).to include("last_name")
          expect(response.body).to include("date_of_birth")
          expect(response.body).to include("case_number")
        end
      end

      it "returns unprocessable content for missing fields" do
        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Daph", # required
              middle_name: "",
              last_name: "", # required
              date_of_birth: { month: "", day: "", year: "" }, # required
              case_number: "" # required
            }
          }
        }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "shows validation errors for required fields" do
        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Daph",
              middle_name: "",
              last_name: "",
              date_of_birth: { month: "", day: "", year: "" },
              case_number: ""
            }
          }
        }
        aggregate_failures do
          expect(response.body).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.first_name.blank"))
          expect(response.body).not_to include(I18n.t("cbv.applicant_informations.sandbox.fields.middle_name.blank"))
          expect(response.body).to include(I18n.t("cbv.applicant_informations.sandbox.fields.last_name.blank"))
          expect(response.body).to include(I18n.t("cbv.applicant_informations.sandbox.fields.date_of_birth.blank"))
          expect(response.body).to include(I18n.t("cbv.applicant_informations.sandbox.fields.case_number.blank"))
        end
      end

      it "redirects to summary when fields are satisfied" do
        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Daph", # required
              middle_name: "",
              last_name: "Gold", # required
              date_of_birth: {
                month: "03",
                day: "19",
                year: "1992"
              }, # required
              case_number: "9971" # required
            }
          }
        }

        expect(response).to redirect_to(cbv_flow_summary_path)
      end

      it "tracks ApplicantSubmittedInformationPage event on successful submission" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantSubmittedInformationPage", anything, anything)

        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Daph",
              middle_name: "",
              last_name: "Gold",
              date_of_birth: {
                month: "03",
                day: "19",
                year: "1992"
              },
              case_number: "9971"
            }
          }
        }

        expect(EventTrackingJob).to have_received(:perform_later).with("ApplicantSubmittedInformationPage", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          cbv_applicant_id: cbv_flow.cbv_applicant_id,
          client_agency_id: cbv_flow.client_agency_id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          identity_age_range_applicant: "30-39"
        ))
      end

      it "does not track ApplicantSubmittedInformationPage event on failed submission" do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantSubmittedInformationPage", anything, anything)

        post :update, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Daph",
              middle_name: "",
              last_name: "", # required but missing
              date_of_birth: {
                month: "03",
                day: "19",
                year: "1992"
              },
              case_number: "9971"
            }
          }
        }

        expect(EventTrackingJob).not_to have_received(:perform_later).with("ApplicantSubmittedInformationPage", anything, anything)
      end

      it "renders form when force_show parameter is present" do
        get :show, params: {
          cbv_applicant_sandbox: {
            cbv_applicant: {
              first_name: "Daph", # required
              middle_name: "",
              last_name: "Gold", # required
              date_of_birth: {
                month: "01",
                day: "01",
                year: "1980"
              }, # required
              case_number: "9971" # required
            }
          },
          force_show: true
        }

        aggregate_failures do
          expect(response.body).to include("first_name")
          expect(response.body).to include("middle_name")
          expect(response.body).to include("last_name")
          expect(response.body).to include("case_number")
        end
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

  describe "#update for LA LDH flow" do
    let(:cbv_flow) { create(:cbv_flow, client_agency_id: "la_ldh") }

    before do
      session[:cbv_flow_id] = cbv_flow.id
    end

    it "tracks event and redirects for LA LDH DOB submission" do
      travel_to Date.new(2025, 1, 1) do
        allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
        allow(EventTrackingJob).to receive(:perform_later).with("ApplicantSubmittedInformationPage", anything, anything)

        post :update, params: {
          cbv_applicant_la_ldh: {
            cbv_applicant: {
              date_of_birth: {
                month: "06",
                day: "15",
                year: "1998"
              },
              case_number: "1234567890123"
            }
          }
        }

        aggregate_failures do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantSubmittedInformationPage",
            anything,
            hash_including(
              cbv_flow_id: cbv_flow.id,
              cbv_applicant_id: cbv_flow.cbv_applicant_id,
              client_agency_id: "la_ldh",
              invitation_id: cbv_flow.cbv_flow_invitation_id,
              identity_age_range_applicant: "26-29"
            )
          )
          expect(response).to redirect_to(cbv_flow_summary_path)
        end
      end
    end
  end
end
