require 'rails_helper'

RSpec.describe Cbv::SessionsController, type: :controller do
  render_views

  describe 'POST #refresh' do
    it 'updates last_seen time and returns ok status' do
      initial_time = Time.current
      session[:last_seen] = initial_time

      post :refresh

      # Verify session was updated
      expect(session[:last_seen]).to be > initial_time
      expect(session[:last_seen]).to be_within(1.second).of(Time.current)
      expect(response).to have_http_status(:ok)
      expect(response.body).to be_blank
    end
  end

  describe 'DELETE #end' do
    before do
      session[:cbv_flow_id] = create(:cbv_flow, :invited).id
    end

    context 'when timeout is true' do
      it 'clears session and sets a notice without tracking timeout event' do
        expect(controller).not_to receive(:track_timeout_event)
        delete :end, params: { timeout: 'true' }
        expect(session[:cbv_flow_id]).to be_nil
      end

      it 'redirects to session timeout page with agency' do
        delete :end, params: { timeout: 'true' }
        expect(response).to redirect_to(cbv_flow_session_timeout_path(client_agency_id: "sandbox"))
      end
    end

    context 'when timeout is not true' do
      it 'clears session without tracking timeout event' do
        expect(controller).not_to receive(:track_timeout_event)
        delete :end
        expect(session[:cbv_flow_id]).to be_nil
      end
    end

    context 'when flow is missing' do
      it 'redirects to root with timeout flag' do
        session[:cbv_flow_id] = nil

        delete :end

        expect(response).to redirect_to(root_url(cbv_flow_timeout: true))
      end
    end
  end

  describe 'GET #timeout' do
    context 'you come to the timeout page with a session' do
      before do
        session[:cbv_flow_id] = create(:cbv_flow, :invited).id
      end

      it 'removes the session' do
        get :timeout
        expect(session[:cbv_flow_id]).to be_nil
      end
    end

    context 'with a valid client_agency_id param' do
      it 'renders the timeout page with start over link' do
        get :timeout, params: { client_agency_id: 'sandbox' }
        expect(response.body).to include('click here')
      end
    end

    context 'with domain detection' do
      it 'uses the detected agency' do
        allow(controller).to receive(:detect_client_agency_from_domain).and_return('sandbox')

        get :timeout
        expect(response.body).to include('click here')
      end
    end

    context 'without a client_agency_id param or domain match' do
      it 'renders the timeout page without link to start over' do
        get :timeout
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('click here')
      end
    end
  end
end
