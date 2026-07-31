require "rails_helper"

RSpec.describe DataRetentionService do
  describe "#redact_invitations" do
    let!(:cbv_flow_invitation) do
      create(:cbv_flow_invitation, :sandbox)
    end
    let(:service) { described_class.new }
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
            auth_token: cbv_flow_invitation.auth_token,
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

        context "when the applicant has another active invitation" do
          before do
            create(
              :cbv_flow_invitation,
              cbv_applicant: cbv_flow_invitation.cbv_applicant,
              expires_at: now + 1.day
            )
          end

          it "keeps the applicant information available" do
            service.redact_invitations

            expect(cbv_flow_invitation.reload).to have_attributes(
              email_address: "REDACTED@example.com",
              redacted_at: within(1.second).of(now)
            )
            expect(cbv_flow_invitation.cbv_applicant.reload).to have_attributes(
              first_name: "Jane",
              redacted_at: nil
            )
          end
        end

        context "when the applicant has an active standalone flow" do
          let!(:active_flow) do
            create(
              :cbv_flow,
              cbv_applicant: cbv_flow_invitation.cbv_applicant,
              cbv_flow_invitation: nil
            )
          end

          it "keeps the applicant information available" do
            service.redact_invitations

            expect(cbv_flow_invitation.reload).to have_attributes(
              email_address: "REDACTED@example.com",
              redacted_at: within(1.second).of(now)
            )
            expect(active_flow.reload.redacted_at).to be_nil
            expect(cbv_flow_invitation.cbv_applicant.reload).to have_attributes(
              first_name: "Jane",
              redacted_at: nil
            )
          end
        end

        it "skips the invitation if it has already been redacted" do
          cbv_flow_invitation.redact!

          expect_any_instance_of(CbvFlowInvitation)
            .not_to receive(:redact!)
          service.redact_invitations
        end
      end
    end

    context "for a used invitation (with associated CbvFlows)" do
      before do
        CbvFlow.create_from_invitation(cbv_flow_invitation, "test_device_id")
      end

      context "after the deletion threshold" do
        let(:now) { cbv_flow_invitation.expires_at + 7.days + 1.minute }

        it "redacts the invitation without redacting the applicant" do
          service.redact_invitations

          expect(cbv_flow_invitation.reload).to have_attributes(
            auth_token: cbv_flow_invitation.auth_token,
            redacted_at: within(1.second).of(Time.now)
          )
          expect(cbv_flow_invitation.cbv_applicant.reload.redacted_at).to be_nil
        end
      end
    end
  end

  describe "#redact_incomplete_cbv_flows" do
    let!(:cbv_flow_invitation) do
      create(:cbv_flow_invitation)
    end
    let!(:cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation, "test_device_id") }
    let(:service) { described_class.new }
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
        payroll_account = create(:payroll_account, flow: cbv_flow)

        expect { service.redact_incomplete_cbv_flows }
          .not_to change { payroll_account.reload.attributes }
      end
    end

    context "after the deletion threshold" do
      let(:now) { deletion_threshold + 1.minute }

      before do
        cbv_flow.update(
          end_user_id: "11111111-1111-1111-1111-111111111111"
        )
      end

      it "redacts the incomplete CbvFlow" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow.reload).to have_attributes(
          end_user_id: "00000000-0000-0000-0000-000000000000"
        )
      end

      it "redacts the associated invitation" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow_invitation.reload).to have_attributes(
          auth_token: cbv_flow_invitation.auth_token,
          redacted_at: within(1.second).of(now)
        )
      end

      it "redacts the associated CbvApplicant" do
        service.redact_incomplete_cbv_flows
        expect(cbv_flow.cbv_applicant.reload).to have_attributes(
          first_name: "REDACTED"
        )
      end

      context "when the applicant has another active invitation" do
        before do
          create(
            :cbv_flow_invitation,
            cbv_applicant: cbv_flow.cbv_applicant,
            expires_at: now + 1.day
          )
        end

        it "keeps the applicant information available" do
          service.redact_incomplete_cbv_flows

          expect(cbv_flow.reload).to have_attributes(
            end_user_id: "00000000-0000-0000-0000-000000000000",
            redacted_at: within(1.second).of(now)
          )
          expect(cbv_flow_invitation.reload).to have_attributes(
            redacted_at: within(1.second).of(now)
          )
          expect(cbv_flow.cbv_applicant.reload).to have_attributes(
            first_name: "Jane",
            redacted_at: nil
          )
        end
      end

      it "redacts an associated PayrollAccount" do
        payroll_account = create(:payroll_account, flow: cbv_flow)
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

        it "redacts the invitation without redacting the applicant" do
          service.redact_invitations

          expect(cbv_flow_invitation.reload).to have_attributes(
            auth_token: cbv_flow_invitation.auth_token,
            redacted_at: within(1.second).of(now)
          )
          expect(cbv_flow.cbv_applicant.reload.redacted_at).to be_nil
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
            end_user_id: "00000000-0000-0000-0000-000000000000"
          )
        end

        it "redacts the associated CbvApplicant" do
          service.redact_incomplete_cbv_flows
          expect(cbv_flow.cbv_applicant.reload).to have_attributes(
            first_name: "REDACTED"
          )
        end

        it "redacts an associated PayrollAccount" do
          payroll_account = create(:payroll_account, flow: cbv_flow)
          service.redact_incomplete_cbv_flows
          expect(payroll_account.reload).to have_attributes(
            redacted_at: within(1.second).of(now)
          )
        end

        context "when the applicant has an active invitation" do
          before do
            create(
              :cbv_flow_invitation,
              cbv_applicant: cbv_flow.cbv_applicant,
              expires_at: now + 1.day
            )
          end

          it "keeps the applicant information available" do
            service.redact_incomplete_cbv_flows

            expect(cbv_flow.reload).to have_attributes(
              end_user_id: "00000000-0000-0000-0000-000000000000",
              redacted_at: within(1.second).of(now)
            )
            expect(cbv_flow.cbv_applicant.reload).to have_attributes(
              first_name: "Jane",
              redacted_at: nil
            )
          end
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
        .create_from_invitation(cbv_flow_invitation, "test_device_id")
        .tap do |cbv_flow|
          cbv_flow.update(
            end_user_id: "11111111-1111-1111-1111-111111111111",
            confirmation_code: "SANDBOX0002",
            transmitted_at: Time.new(2024, 8, 1, 12, 0, 0, "-04:00")
          )
        end
    end
    let(:service) { described_class.new }
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
        payroll_account = create(:payroll_account, flow: cbv_flow)

        expect { service.redact_complete_cbv_flows }
          .not_to change { payroll_account.reload.attributes }
      end
    end

    context "after the deletion threshold" do
      let(:now) { deletion_threshold + 1.minute }

      context "when the invitation is still valid" do
        # The factory default expires_at is several days from now (creation time),
        # so no setup is needed — the invitation is live by default.
        it "does not redact the associated applicant" do
          service.redact_complete_cbv_flows
          expect(cbv_flow.cbv_applicant.reload.redacted_at).to be_nil
        end
      end

      it "redacts the incomplete CbvFlow" do
        service.redact_complete_cbv_flows
        expect(cbv_flow.reload).to have_attributes(
          end_user_id: "00000000-0000-0000-0000-000000000000"
        )
      end

      it "does not redact the associated invitation before it expires" do
        service.redact_complete_cbv_flows
        expect(cbv_flow_invitation.reload.redacted_at).to be_nil
      end

      context "when the invitation has expired" do
        before do
          cbv_flow_invitation.update!(expires_at: cbv_flow.transmitted_at - 1.day)
        end

        it "redacts the associated applicant" do
          service.redact_complete_cbv_flows
          expect(cbv_flow.cbv_applicant.reload).to have_attributes(
            first_name: "REDACTED"
          )
        end
      end

      it "redacts an associated PayrollAccount" do
        payroll_account = create(:payroll_account, flow: cbv_flow)
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

  describe "#redact_activity_flow_summaries" do
    let(:service) { described_class.new }
    let(:now) { Time.now }
    let!(:activity_flow) { create(:activity_flow) }
    let!(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow) }
    let!(:summary) do
      create(:activity_flow_monthly_summary,
        activity_flow: activity_flow,
        payroll_account: payroll_account,
        total_w2_hours: 40.0,
        accrued_gross_earnings_cents: 500_00)
    end
    let!(:employment_summary) do
      create(:activity_flow_employment_summary,
        activity_flow: activity_flow,
        payroll_account: payroll_account,
        employer_name: "Acme Corp")
    end

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    context "before the deletion threshold" do
      let(:now) { activity_flow.updated_at + 7.days - 1.minute }

      it "does not redact monthly summaries" do
        expect { service.redact_activity_flow_summaries }
          .not_to change { summary.reload.attributes }
      end
    end

    context "after the deletion threshold" do
      let(:now) { activity_flow.updated_at + 7.days + 1.minute }

      it "redacts monthly summaries" do
        service.redact_activity_flow_summaries

        expect(summary.reload).to have_attributes(
          total_w2_hours: 0.0,
          accrued_gross_earnings_cents: 0,
          redacted_at: be_present
        )
      end

      it "redacts employment summaries" do
        service.redact_activity_flow_summaries

        expect(employment_summary.reload).to have_attributes(
          employer_name: "REDACTED",
          redacted_at: be_present
        )
      end

      it "redacts associated payroll accounts" do
        service.redact_activity_flow_summaries

        expect(payroll_account.reload).to have_attributes(
          redacted_at: be_present
        )
      end
    end

    context "when summaries are already redacted" do
      let(:now) { activity_flow.updated_at + 8.days }

      before do
        summary.redact!
        employment_summary.redact!
      end

      it "does not re-process the activity flow" do
        expect { service.redact_activity_flow_summaries }
          .not_to change { summary.reload.attributes }
      end
    end

    context "when monthly summaries are already redacted" do
      let(:now) { activity_flow.updated_at + 8.days }

      before do
        summary.redact!
      end

      it "redacts remaining unredacted employment summaries" do
        service.redact_activity_flow_summaries

        expect(employment_summary.reload).to have_attributes(
          employer_name: "REDACTED",
          redacted_at: be_present
        )
      end
    end
  end

  describe ".manually_redact_by_case_number!" do
    let(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "DELETEME001" }) }
    let!(:cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation, "test_device_id") }
    let!(:second_cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation, "test_device_id_2") }
    let!(:payroll_account) { create(:payroll_account, flow: second_cbv_flow) }

    it "redacts the invitation and all flow objects" do
      described_class.manually_redact_by_case_number!("DELETEME001")

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

    context "with activity flow summaries" do
      let(:applicant) { cbv_flow_invitation.cbv_applicant }
      let!(:activity_flow) { create(:activity_flow, cbv_applicant: applicant) }
      let!(:activity_payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow) }
      let!(:summary) do
        create(:activity_flow_monthly_summary,
          activity_flow: activity_flow,
          payroll_account: activity_payroll_account,
          total_w2_hours: 40.0)
      end
      let!(:employment_summary) do
        create(:activity_flow_employment_summary,
          activity_flow: activity_flow,
          payroll_account: activity_payroll_account,
          employer_name: "Acme Corp")
      end

      it "redacts activity flow summaries and payroll accounts" do
        described_class.manually_redact_by_case_number!("DELETEME001")

        expect(summary.reload).to have_attributes(
          total_w2_hours: 0.0,
          redacted_at: be_present
        )
        expect(employment_summary.reload).to have_attributes(
          employer_name: "REDACTED",
          redacted_at: be_present
        )
        expect(activity_payroll_account.reload).to have_attributes(
          redacted_at: be_present
        )
      end
    end
  end

  describe "#delete_delivered_documents" do
    let(:service) { described_class.new }
    let(:now) { Time.current }
    let(:transmitted_at) { 8.days.ago }
    let!(:activity_flow) { create(:activity_flow, completed_at: 8.days.ago, transmitted_at: transmitted_at) }
    let!(:volunteering_activity) { create(:volunteering_activity, activity_flow: activity_flow) }

    def attach_document(activity)
      activity.document_uploads.attach(
        io: StringIO.new("hello"),
        filename: "proof.txt",
        content_type: "text/plain"
      )
      activity.document_uploads_attachments.last
    end

    around do |ex|
      Timecop.freeze(now, &ex)
    end

    context "for a delivered flow past the retention window" do
      let!(:attachment) { attach_document(volunteering_activity) }
      let(:blob) { attachment.blob }

      it "purges the uploaded documents" do
        expect { service.delete_delivered_documents }
          .to change { volunteering_activity.reload.document_uploads.attached? }
          .from(true).to(false)
      end

      it "removes the blob and its stored file" do
        service.delete_delivered_documents

        expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
        expect(blob.service.exist?(blob.key)).to be(false)
      end

      it "marks the flow's documents as deleted" do
        expect { service.delete_delivered_documents }
          .to change { activity_flow.reload.documents_deleted_at }
          .from(nil).to(be_present)
      end

      it "logs the activity flow id and deleted keys" do
        allow(Rails.logger).to receive(:info)

        service.delete_delivered_documents

        expect(Rails.logger).to have_received(:info)
          .with(a_string_including("activity_flow_id=#{activity_flow.id}", blob.key))
      end
    end

    context "when the flow was transmitted within the retention window" do
      let(:transmitted_at) { 6.days.ago }

      before { attach_document(volunteering_activity) }

      it "does not purge documents or mark the flow" do
        service.delete_delivered_documents

        expect(volunteering_activity.reload.document_uploads.attached?).to be(true)
        expect(activity_flow.reload.documents_deleted_at).to be_nil
      end
    end

    context "when the flow was completed but never transmitted" do
      let(:transmitted_at) { nil }

      before { attach_document(volunteering_activity) }

      it "does not purge documents" do
        service.delete_delivered_documents

        expect(activity_flow.reload.completed_at).to be_present
        expect(volunteering_activity.reload.document_uploads.attached?).to be(true)
        expect(activity_flow.reload.documents_deleted_at).to be_nil
      end
    end

    context "when the flow's documents were already deleted" do
      before { activity_flow.update_column(:documents_deleted_at, 1.day.ago) }

      it "does not re-process the flow" do
        expect { service.delete_delivered_documents }
          .not_to change { activity_flow.reload.documents_deleted_at }
      end
    end

    context "when purging one document fails" do
      let!(:failing_attachment) { attach_document(volunteering_activity) }
      let!(:other_attachment) { attach_document(volunteering_activity) }

      before do
        failing_key = failing_attachment.blob.key

        allow_any_instance_of(ActiveStorage::Attachment).to receive(:purge).and_wrap_original do |method, *args|
          raise "storage unavailable" if method.receiver.blob.key == failing_key

          method.call(*args)
        end
      end

      it "purges the remaining documents and logs the failure" do
        allow(Rails.logger).to receive(:error)

        service.delete_delivered_documents

        expect(ActiveStorage::Blob.exists?(other_attachment.blob_id)).to be(false)
        expect(ActiveStorage::Blob.exists?(failing_attachment.blob_id)).to be(true)
        expect(Rails.logger).to have_received(:error)
          .with(a_string_including("key=#{failing_attachment.blob.key}", "storage unavailable"))
      end

      it "does not mark the flow's documents as deleted" do
        service.delete_delivered_documents

        expect(activity_flow.reload.documents_deleted_at).to be_nil
      end
    end

    context "when a flow raises while its documents are being deleted" do
      let!(:other_flow) { create(:activity_flow, completed_at: 8.days.ago, transmitted_at: transmitted_at) }
      let!(:other_activity) { create(:volunteering_activity, activity_flow: other_flow) }

      before do
        attach_document(volunteering_activity)
        attach_document(other_activity)

        failing_flow_id = activity_flow.id

        allow_any_instance_of(ActivityFlow).to receive(:update_column).and_wrap_original do |method, *args|
          raise ActiveRecord::StatementInvalid, "connection lost" if method.receiver.id == failing_flow_id

          method.call(*args)
        end
      end

      it "logs the failure and processes the remaining flows" do
        allow(Rails.logger).to receive(:error)

        service.delete_delivered_documents

        expect(Rails.logger).to have_received(:error).with(
          a_string_including(
            "Failed to delete delivered documents for activity_flow_id=#{activity_flow.id}",
            "connection lost"
          )
        )
        expect(other_flow.reload.documents_deleted_at).to be_present
        expect(activity_flow.reload.documents_deleted_at).to be_nil
      end
    end
  end

  describe ".redact_case_numbers_by_agency" do
    let(:agency_to_redact) { "sandbox" }
    let!(:cbv_flow_invitation) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "DELETEME001", client_agency_id: agency_to_redact }) }
    let!(:cbv_flow_invitation2) { create(:cbv_flow_invitation, cbv_applicant_attributes: { case_number: "DELETEME002", client_agency_id: agency_to_redact }) }
    let!(:cbv_flow) { CbvFlow.create_from_invitation(cbv_flow_invitation, "test_device_id") }
    let!(:cbv_flow2) { CbvFlow.create_from_invitation(cbv_flow_invitation2, "test_device_id_2") }

    it "redacts all case numbers for a given agency" do
      described_class.redact_case_numbers_by_agency(agency_to_redact)
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
