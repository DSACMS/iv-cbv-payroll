require "rails_helper"

RSpec.describe "backfills.rake" do
  describe "backfills:cbv_applicants" do
    def expect_cbv_applicant_attributes_match(invitation)
      expect(invitation.cbv_applicant).to have_attributes(
        case_number: invitation.case_number,
        client_id_number: invitation.client_id_number,
        first_name: invitation.first_name,
        middle_name: invitation.middle_name,
        last_name: invitation.last_name,
        agency_id_number: invitation.agency_id_number,
        snap_application_date: invitation.snap_application_date,
        beacon_id: invitation.beacon_id
      )
    end

    context "when there are backfills" do
      # produce an invalid cbv_flow_invitation
      let(:invalid_cbv_flow_invitation) do
        invitation = build(:cbv_flow_invitation, {
          user: nil,
          language: nil,
          case_number: nil,
          client_id_number: nil,
          first_name: "Foo",
          last_name: "Bar",
          snap_application_date: 31.days.ago.to_date,
          cbv_applicant: nil # intentionally don't create one to test the backfill
        })
        invitation.save(validate: false)
        invitation
      end

      let(:redacted_cbv_flow_invitation) do
        invitation = create(
          :cbv_flow_invitation,
          cbv_applicant: nil,
          first_name: "Foo",
          last_name: "Bar",
          snap_application_date: "2024-01-01"
        )
        invitation.redact!
        invitation
      end

      it "Back-fills cbv_applicants from an invalid cbv_flow_invitation" do
        expect(invalid_cbv_flow_invitation.cbv_applicant).to be_nil
        expect(invalid_cbv_flow_invitation.valid?).to eq(false)
        Rake::Task['backfills:cbv_applicants'].execute
        invalid_cbv_flow_invitation.reload
        expect(invalid_cbv_flow_invitation.cbv_applicant).to be_present
        expect_cbv_applicant_attributes_match(invalid_cbv_flow_invitation)
      end

      it "Back-fills cbv_applicants from a valid cbv_flow_invitation" do
        expect(redacted_cbv_flow_invitation.cbv_applicant).to be_nil
        Rake::Task['backfills:cbv_applicants'].execute
        redacted_cbv_flow_invitation.reload
        expect(redacted_cbv_flow_invitation.cbv_applicant).to be_present
        expect_cbv_applicant_attributes_match(redacted_cbv_flow_invitation)
      end
    end
  end
end
