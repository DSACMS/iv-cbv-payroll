require "rails_helper"

RSpec.describe Cbv::GenericLinksController do
  before do
    allow(EventTrackingJob).to receive(:perform_later)
  end
  describe '#show' do
    context 'when the hostname matches a client agency domain and the pilot is active' do
      context 'when no existing CBV applicant cookie exists' do
        before do
          get :show, params: { client_agency_id: "sandbox" }
        end

        it "starts a CBV flow with new applicant" do
          expect(response).to redirect_to(cbv_flow_entry_path)
          expect(assigns(:cbv_flow).client_agency_id).to eq("sandbox")
        end

        it "sets an encrypted permanent cookie with cbv_applicant_id" do
          cbv_flow = assigns(:cbv_flow)

          expect(cookies.encrypted[:cbv_applicant_id]).to eq(cbv_flow.cbv_applicant_id)

          cookie_jar = response.cookies["cbv_applicant_id"]
          expect(cookie_jar).to be_present
        end

        it "tracks ApplicantClickedGenericLink event with is_new_session: true" do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            hash_including(
              cbv_applicant_id: assigns(:cbv_flow).cbv_applicant_id,
              cbv_flow_id: assigns(:cbv_flow).id,
              client_agency_id: "sandbox",
              is_new_session: true
            )
          )
        end
      end

      context 'when existing CBV applicant cookie exists' do
        let!(:existing_applicant) { create(:cbv_applicant, :sandbox, case_number: "12345", first_name: "John") }

        before do
          cookies.encrypted[:cbv_applicant_id] = existing_applicant.id
          get :show, params: { client_agency_id: "sandbox" }
        end

        it "reuses existing applicant" do
          expect(assigns(:cbv_flow).cbv_applicant_id).to eq(existing_applicant.id)
        end

        it "clears applicant information fields" do
          existing_applicant.reload
          expect(existing_applicant.case_number).to be_nil
          expect(existing_applicant.first_name).to be_nil
        end

        it "tracks ApplicantClickedGenericLink event with is_new_session: false" do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            hash_including(
              cbv_applicant_id: existing_applicant.id,
              is_new_session: false
            )
          )
        end
      end

      context 'when existing CBV applicant cookie exists but applicant not found' do
        before do
          cookies.encrypted[:cbv_applicant_id] = 99999
          get :show, params: { client_agency_id: "sandbox" }
        end

        it "creates new applicant instead of reusing" do
          expect(assigns(:cbv_flow).cbv_applicant_id).not_to eq(99999)
          expect(assigns(:cbv_flow).client_agency_id).to eq("sandbox")
        end

        it "tracks event with is_new_session: true" do
          expect(EventTrackingJob).to have_received(:perform_later).with(
            "ApplicantClickedGenericLink",
            anything,
            hash_including(is_new_session: true)
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
