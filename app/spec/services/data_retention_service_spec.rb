require "rails_helper"

RSpec.describe DataRetentionService do
  describe "#redact_invitations" do
    let!(:cbv_flow_invitation) do
      create(:cbv_flow_invitation, :sandbox)
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
            auth_token: "REDACTED",
            redacted_at: within(1.second).of(Time.now)
          )
        end

        it "redacts the associated CbvApplicant" do
          service.redact_invitations
          expect(cbv_flow_invitation.cbv_applicant.reload).to have_attributes(
            first_name: "REDACTED",
            redacted_at: within(1.second).of(Time.now)
          )
        end

        it "skips the invitation if it has already been redacted" do
          cbv_flow_invitation.redact!

          expect_any_instance_of(CbvFlowInvitation)
            .not_to receive(:redact!)
          service.redact_invitations
        end
      end
    end
  end

  describe "#redact_incomplete_cbv_flows" do
    let!(:cbv_flow_invitation) do
      create(:cbv_flow_invitation)
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

      it "does not redact the CbvFlowInvitation" do
        expect { service.redact_incomplete_cbv_flows }
          .not_to change { cbv_flow_invitation.reload.attributes }
      end

      it "does not redact the CbvApplicant" do
        expect { service.redact_incomplete_cbv_flows }
          .not_to change { cbv_flow.cbv_applicant.reload.attributes }
      end

      it "does not redact an associated PayrollAccount" do
        payroll_account = create(:payroll_account, cbv_flow: cbv_flow)

        expect { service.redact_incomplete_cbv_flows }
          .not_to change { payroll_account.reload.attributes }
      end
    end

    context "after the deletion threshold" do
      let(:now) { deletion_threshold + 1.minute }

      before do
        cbv_flow.update(
          end_user_id: "11111111-1111-1111-1111-111111111111",
          additional_information: { "account-id" => "some string here" }
        )
      end

      it "redacts the incomplete CbvFlow" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow.reload).to have_attributes(
          end_user_id: "00000000-0000-0000-0000-000000000000",
          additional_information: {}
        )
      end

      it "redacts the associated invitation" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow_invitation.reload).to have_attributes(
          auth_token: "REDACTED",
          redacted_at: within(1.second).of(now)
        )
      end

      it "redacts the associated CbvApplicant" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow.cbv_applicant.reload).to have_attributes(
          first_name: "REDACTED"
        )
      end

      it "redacts an associated PayrollAccount" do
        payroll_account = create(:payroll_account, cbv_flow: cbv_flow)
        service.redact_incomplete_cbv_flows
        expect(payroll_account.reload).to have_attributes(
          redacted_at: within(1.second).of(now)
        )
      end

      it "skips redacting already-redacted CbvFlows" do
        service.redact_incomplete_cbv_flows

        expect_any_instance_of(CbvFlow).not_to receive(:redact!)
        service.redact_incomplete_cbv_flows
      end

      context "for a complete CbvFlow" do
        before do
          cbv_flow.update(confirmation_code: "SANDBOX001")
        end

        it "does not redact the CbvFlow" do
          expect { service.redact_invitations }
            .not_to change { cbv_flow.reload.attributes }
        end

        it "does not redact the invitation" do
          expect { service.redact_invitations }
            .not_to change { cbv_flow_invitation.reload.attributes }
        end
      end
    end

    context "when the CbvFlow has no invitation" do
      let(:cbv_flow) { create(:cbv_flow, :invited, cbv_flow_invitation: nil) }
      let(:deletion_threshold) { cbv_flow.updated_at + DataRetentionService::REDACT_UNUSED_INVITATIONS_AFTER }

      context "before the deletion threshold" do
        let(:now) { deletion_threshold - 1.minute }

        it "does not redact the CbvFlow" do
          expect { service.redact_invitations }
            .not_to change { cbv_flow.reload.attributes }
        end
      end

      context "after the deletion threshold" do
        let(:now) { deletion_threshold + 1.minute }

        it "redacts the incomplete CbvFlow" do
          service.redact_incomplete_cbv_flows
          expect(cbv_flow.reload).to have_attributes(
            end_user_id: "00000000-0000-0000-0000-000000000000",
            additional_information: {}
          )
        end

        it "redacts an associated PayrollAccount" do
          payroll_account = create(:payroll_account, cbv_flow: cbv_flow)
          service.redact_incomplete_cbv_flows
          expect(payroll_account.reload).to have_attributes(
            redacted_at: within(1.second).of(now)
          )
        end
      end
    end
  end

  describe "#redact_complete_cbv_flows" do
    let!(:cbv_flow_invitation) do
      create(:cbv_flow_invitation)
    end
    let!(:cbv_flow) do
      CbvFlow
        .create_from_invitation(cbv_flow_invitation)
        .tap do |cbv_flow|
          cbv_flow.update(
            end_user_id: "11111111-1111-1111-1111-111111111111",
            additional_information: { "account-id" => "some string here" },
            confirmation_code: "SANDBOX0002",
            transmitted_at: Time.new(2024, 8, 1, 12, 0, 0, "-04:00")
          )
        end
    end
    let(:service) { DataRetentionService.new }
    let(:deletion_threshold) { cbv_flow.transmitted_at + DataRetentionService::REDACT_TRANSMITTED_CBV_FLOWS_AFTER }
    let(:now) { Time.now }

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    context "before the deletion threshold" do
      let(:now) { deletion_threshold - 1.minute }

      it "does not redact the CbvFlow" do
        expect { service.redact_complete_cbv_flows }
          .not_to change { cbv_flow.reload.attributes }
      end

      it "does not redact the CbvFlowInvitation" do
        expect { service.redact_complete_cbv_flows }
          .not_to change { cbv_flow_invitation.reload.attributes }
      end

      it "does not redact the CbvApplicant" do
        expect { service.redact_complete_cbv_flows }
          .not_to change { cbv_flow.cbv_applicant.reload.attributes }
      end

      it "does not redact an associated PayrollAccount" do
        payroll_account = create(:payroll_account, cbv_flow: cbv_flow)

        expect { service.redact_complete_cbv_flows }
          .not_to change { payroll_account.reload.attributes }
      end
    end

    context "after the deletion threshold" do
      let(:now) { deletion_threshold + 1.minute }

      it "redacts the incomplete CbvFlow" do
        service.redact_complete_cbv_flows
        expect(cbv_flow.reload).to have_attributes(
          end_user_id: "00000000-0000-0000-0000-000000000000",
          additional_information: {}
        )
      end

      it "redacts the associated invitation" do
        service.redact_complete_cbv_flows
        expect(cbv_flow_invitation.reload).to have_attributes(
          auth_token: "REDACTED",
          redacted_at: within(1.second).of(now)
        )
      end

      it "redacts the associated applicant" do
        service.redact_complete_cbv_flows
        expect(cbv_flow.cbv_applicant.reload).to have_attributes(
          first_name: "REDACTED"
        )
      end

      it "redacts an associated PayrollAccount" do
        payroll_account = create(:payroll_account, cbv_flow: cbv_flow)
        service.redact_complete_cbv_flows
        expect(payroll_account.reload).to have_attributes(
          redacted_at: within(1.second).of(now)
        )
      end

      it "skips redacting already-redacted CbvFlows" do
        service.redact_complete_cbv_flows

        expect_any_instance_of(CbvFlow).not_to receive(:redact!)
        service.redact_complete_cbv_flows
      end
    end
  end

  describe ".manually_redact_by_case_number!" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "DELETEME001" }) }
    let!(:cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation) }
    let!(:second_cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation) }
    let!(:payroll_account) { create(:payroll_account, cbv_flow: second_cbv_flow) }

    it "redacts the invitation and all flow objects" do
      DataRetentionService.manually_redact_by_case_number!("DELETEME001")

      expect(cbv_flow.reload).to have_attributes(
        redacted_at: within(1.second).of(Time.now)
      )
      expect(cbv_flow.cbv_applicant.reload).to have_attributes(
        first_name: "REDACTED",
        redacted_at: within(1.second).of(Time.now)
      )
      expect(second_cbv_flow.reload).to have_attributes(
        redacted_at: within(1.second).of(Time.now)
      )
      expect(cbv_flow_invitation.reload).to have_attributes(
        redacted_at: within(1.second).of(Time.now)
      )
      expect(payroll_account.reload).to have_attributes(
        redacted_at: within(1.second).of(Time.now)
      )
    end
  end

  describe ".redact_case_numbers_by_agency" do
    let(:agency_to_redact) { "sandbox" }
    let!(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "DELETEME001", client_agency_id: agency_to_redact }) }
    let!(:cbv_flow_invitation2) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "DELETEME002", client_agency_id: agency_to_redact }) }
    let!(:cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation) }
    let!(:cbv_flow2) { CbvFlow.create_from_invitation(cbv_flow_invitation2) }

    it "redacts all case numbers for a given agency" do
      DataRetentionService.redact_case_numbers_by_agency(agency_to_redact)
      expect(cbv_flow.cbv_applicant.reload).to have_attributes(
        case_number: "REDACTED",
        redacted_at: within(1.second).of(Time.now)
      )
      expect(cbv_flow2.cbv_applicant.reload).to have_attributes(
        case_number: "REDACTED",
        redacted_at: within(1.second).of(Time.now)
      )
    end
  end
end
