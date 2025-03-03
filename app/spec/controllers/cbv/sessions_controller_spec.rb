require 'rails_helper'

RSpec.describe Cbv::SessionsController, type: :controller do
  describe 'POST #refresh' do
    context 'with turbo_stream format' do
      it 'updates last_seen time and returns ok status' do
        post :refresh, format: :turbo_stream
        expect(session[:last_seen]).to be_within(1.second).of(Time.current)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'DELETE #end' do
    before do
      session[:cbv_flow_id] = 'test_flow_id'
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
