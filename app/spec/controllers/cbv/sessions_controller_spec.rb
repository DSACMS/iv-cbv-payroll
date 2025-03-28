require 'rails_helper'

RSpec.describe Cbv::SessionsController, type: :controller do
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
      it 'tracks timeout event and clears session' do
        expect(controller).to receive(:track_timeout_event)
        delete :end, params: { timeout: 'true' }
        expect(session[:cbv_flow_id]).to be_nil
      end
    end

    context 'when timeout is not true' do
      it 'clears session without tracking timeout event' do
        expect(controller).not_to receive(:track_timeout_event)
        delete :end
        expect(session[:cbv_flow_id]).to be_nil
      end
    end
  end
end
