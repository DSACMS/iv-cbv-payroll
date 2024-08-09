require "rails_helper"

RSpec.describe DataRetentionService do
  describe "#redact_invitations" do
    let!(:cbv_flow_invitation) do
      CbvFlowInvitation.create!(
        case_number: "ABC1234",
        email_address: "tom@example.com",
        site_id: "sandbox",
        created_at: Time.new(2024, 8, 1, 12, 0, 0, "-04:00")
      )
    end
    let(:service) { DataRetentionService.new }
    let(:now) { Time.now }

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    context "for an unused invitation (no associated CbvFlow)" do
      context "before the deletion threshold" do
        let(:now) { cbv_flow_invitation.expires_at + 7.days - 1.minute }

        it "does not redact the invitation" do
          expect { service.redact_invitations }
            .not_to change { cbv_flow_invitation.reload.attributes }
        end
      end

      context "after the deletion threshold" do
        let(:now) { cbv_flow_invitation.expires_at + 7.days + 1.minute }

        it "redacts the invitation" do
          service.redact_invitations
          expect(cbv_flow_invitation.reload).to have_attributes(
            email_address: "REDACTED@example.com",
            case_number: "REDACTED",
            auth_token: "REDACTED"
          )
        end
      end
    end
  end

  describe "#redact_incomplete_cbv_flows" do
    let!(:cbv_flow_invitation) do
      CbvFlowInvitation.create!(
        case_number: "ABC1234",
        email_address: "tom@example.com",
        site_id: "sandbox",
        created_at: Time.new(2024, 8, 1, 12, 0, 0, "-04:00")
      )
    end
    let!(:cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation) }
    let(:service) { DataRetentionService.new }
    let(:deletion_threshold) { cbv_flow_invitation.expires_at + DataRetentionService::REDACT_UNUSED_INVITATIONS_AFTER }
    let(:now) { Time.now }

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    context "before the deletion threshold" do
      let(:now) { deletion_threshold - 1.minute }

      it "does not redact the CbvFlow" do
        expect { service.redact_incomplete_cbv_flows }
          .not_to change { cbv_flow.reload.attributes }
      end
    end

    context "after the deletion threshold" do
      let(:now) { deletion_threshold + 1.minute }

      before do
        cbv_flow.update(
          pinwheel_end_user_id: "11111111-1111-1111-1111-111111111111",
          additional_information: { "account-id" => "some string here" }
        )
      end

      it "redacts the incomplete CbvFlow" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow.reload).to have_attributes(
          case_number: "REDACTED",
          pinwheel_end_user_id: "00000000-0000-0000-0000-000000000000",
          additional_information: {}
        )
      end

      it "redacts the associated invitation" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow_invitation.reload).to have_attributes(
          case_number: "REDACTED"
        )
      end

      context "for a complete CbvFlow" do
        before do
          cbv_flow.update(confirmation_code: "SANDBOX001")
        end

        it "does not redact the invitation" do
          expect { service.redact_invitations }
            .not_to change { cbv_flow_invitation.reload.attributes }
        end
      end
    end
  end
end
