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
end
