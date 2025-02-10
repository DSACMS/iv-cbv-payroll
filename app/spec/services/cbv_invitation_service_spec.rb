require "rails_helper"

RSpec.describe CbvInvitationService, type: :service do
  let(:event_logger) { instance_double('GenericEventTracker') }
  let(:service) { described_class.new(event_logger) }
  let(:cbv_flow_invitation_params) do
    attributes_for(:cbv_flow_invitation).merge(
      cbv_applicant_attributes: attributes_for(:cbv_applicant)
    )
  end
  let(:current_user) { create(:user) }

  before do
    allow(event_logger).to receive(:track)
  end

  describe '#invite' do
    context 'when delivery method is :email' do
      it 'creates an invitation with correct parameters' do
        service.invite(
          cbv_flow_invitation_params,
          current_user,
          delivery_method: :email
        )

        invitation = CbvFlowInvitation.last
        expect(invitation).to have_attributes(
          user: current_user,
          case_number: cbv_flow_invitation_params[:case_number]
        )
      end

      it 'sends an email invitation' do
        expect do
          service.invite(
            cbv_flow_invitation_params,
            current_user,
            delivery_method: :email
          )
        end.to change { ActionMailer::Base.deliveries.count }
          .by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to include(cbv_flow_invitation_params[:email_address])
      end

      it 'tracks the event' do
        service.invite(
          cbv_flow_invitation_params,
          current_user,
          delivery_method: :email
        )

        invitation = CbvFlowInvitation.last
        expect(event_logger).to have_received(:track).with(
          'ApplicantInvitedToFlow',
          nil,
          hash_including(invitation_id: invitation.id)
        )
      end
    end

    context 'when delivery method is nil' do
      it 'creates an invitation with correct parameters' do
        service.invite(
          cbv_flow_invitation_params,
          current_user,
          delivery_method: nil
        )

        invitation = CbvFlowInvitation.last
        expect(invitation).to have_attributes(
          user: current_user,
          case_number: cbv_flow_invitation_params[:case_number]
        )
      end

      it 'logs a message instead of sending an email' do
        allow(Rails.logger).to receive(:info)

        expect do
          service.invite(
            cbv_flow_invitation_params,
            current_user,
            delivery_method: nil
          )
        end.to change { ActionMailer::Base.deliveries.count }
          .by(0)

        expect(Rails.logger).to have_received(:info).with(/Generated invitation ID:/)
      end

      it 'tracks the event' do
        service.invite(
          cbv_flow_invitation_params,
          current_user,
          delivery_method: nil
        )

        invitation = CbvFlowInvitation.last
        expect(event_logger).to have_received(:track).with(
          'ApplicantInvitedToFlow',
          nil,
          hash_including(invitation_id: invitation.id)
        )
      end
    end
  end
end
