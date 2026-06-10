require "rails_helper"

RSpec.describe Cbv::GenericLinksController do
  before do
    allow(EventTrackingJob).to receive(:perform_later)
  end

  describe '#show' do
    context 'when the hostname matches a client agency domain and the pilot is active' do
      before do
        stub_client_agency_config_value("sandbox", "generic_links_disabled", false)
        stub_client_agency_config_value("sandbox", "pilot_ended", false)
      end

      it 'assigns flow id and type in session' do
        get :show, params: { client_agency_id: "sandbox" }
        expect(session[:flow_type]).to eq(:cbv)
        expect(session[:flow_id]).to eq(assigns(:cbv_flow).id)
      end

      context 'when generic links are disabled for the agency' do
        before do
          stub_client_agency_config_value("sandbox", "generic_links_disabled", true)
        end

        it 'redirects to the root path' do
          get :show, params: { client_agency_id: "sandbox" }
          expect(response).to redirect_to(root_path)
        end
      end

      context 'when starting from a generic link' do
        let(:headers) { {} }

        before do
          request.headers.merge!(headers)
          get :show, params: { client_agency_id: "sandbox" }
        end

        it "starts a CBV flow with new applicant" do
          expect(response).to redirect_to(cbv_flow_entry_path)
          expect(assigns(:cbv_flow).cbv_applicant.client_agency_id).to eq("sandbox")
        end

        it "tracks ApplicantClickedGenericLink event metadata" do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            hash_including(
              cbv_applicant_id: assigns(:cbv_flow).cbv_applicant_id,
              cbv_flow_id: assigns(:cbv_flow).id,
              client_agency_id: "sandbox"
            )
          )
        end

        context "when the User Agent is nil" do
          let(:headers) { { "User-Agent" => nil } }

          it "tracks the ApplicantClickedGenericLink event" do
            expect(EventTrackingJob).to have_received(:perform_later)
              .with("ApplicantClickedGenericLink", anything, anything)
          end
        end

        context "when the User Agent is Go-Http-Client" do
          let(:headers) { { "User-Agent" => "Go-http-client/1.1" } }

          it "does not track the ApplicantClickedGenericLink event" do
            expect(EventTrackingJob).not_to have_received(:perform_later)
              .with("ApplicantClickedGenericLink", anything, anything)
          end
        end
      end

      context 'when a previous flow exists for the same device' do
        let!(:invitation) do
          create(
            :cbv_flow_invitation,
            :sandbox,
            cbv_applicant_attributes: {
              case_number: "12345",
              first_name: "John"
            }
          )
        end
        let(:existing_applicant) { invitation.cbv_applicant }

        before do
          create(
            :cbv_flow,
            cbv_flow_invitation: invitation,
            cbv_applicant: existing_applicant,
            device_id: "test-device-id"
          )
          cookies.permanent.signed[:device_id] = "test-device-id"
        end

        it "starts a CBV flow with a new applicant" do
          expect do
            get :show, params: { client_agency_id: "sandbox" }
          end.to change(CbvApplicant, :count).by(1)

          expect(assigns(:cbv_flow).cbv_applicant.client_agency_id).to eq("sandbox")
        end

        it "preserves applicant information fields on the previous applicant" do
          get :show, params: { client_agency_id: "sandbox" }

          expect(existing_applicant.reload).to have_attributes(
            case_number: "12345",
            first_name: "John"
          )
        end

        it "tracks ApplicantClickedGenericLink event with the new applicant" do
          get :show, params: { client_agency_id: "sandbox" }

          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            hash_including(
              cbv_applicant_id: assigns(:cbv_flow).cbv_applicant_id
            )
          )
        end
      end

      context 'when device has no previous flow' do
        before do
          get :show, params: { client_agency_id: "sandbox" }
        end

        it "creates a new applicant" do
          expect(assigns(:cbv_flow).cbv_applicant).to be_persisted
        end

        it "tracks the ApplicantClickedGenericLink event" do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            anything
          )
        end
      end

      context 'when origin parameter is provided' do
        before do
          get :show, params: { client_agency_id: "sandbox", origin: "mail" }
        end

        it "includes origin in tracking event" do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            hash_including(origin: "mail")
          )
        end
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
