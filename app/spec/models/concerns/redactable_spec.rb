require "rails_helper"

RSpec.describe Redactable, type: :model do
  let(:invitation) { create(:cbv_flow_invitation) }

  describe "#redact!" do
    context "when an integer field is configured" do
      let(:redactable_model) do
        Class.new(ApplicationRecord) do
          self.table_name = "activity_flow_employment_summaries"

          include Redactable

          has_redactable_fields compensation_amount: :integer
        end
      end
      let(:summary) { create(:activity_flow_employment_summary, compensation_amount: 2_500, employer_name: "Example Employer") }
      let(:record) { redactable_model.find(summary.id) }

      before do
        record.redact!
        record.reload
      end

      it "persists nil in place of the integer value" do
        expect(record.compensation_amount).to be_nil
      end

      it "marks the record as redacted" do
        expect(record.redacted_at).to be_present
      end

      it "preserves fields not configured for redaction" do
        expect(record.employer_name).to eq("Example Employer")
      end
    end

    context "when fields have unique database constraints" do
      let!(:first_identity) { create(:identity, activity_flows_count: 0) }
      let!(:second_identity) { create(:identity, activity_flows_count: 0) }
      let!(:first_household) { create(:household) }
      let!(:second_household) { create(:household) }

      before do
        first_identity.redact!
        second_identity.redact!
        first_household.redact!
        second_household.redact!
      end

      it "persists distinct identity placeholders" do
        expect(first_identity.reload.first_name).to start_with("REDACTED-")
        expect(second_identity.reload.first_name).to start_with("REDACTED-")
        expect(first_identity.first_name).not_to eq(second_identity.first_name)
      end

      it "persists distinct household reference and token placeholders" do
        expect(first_household.reload.reference_id).to start_with("REDACTED-")
        expect(second_household.reload.reference_id).to start_with("REDACTED-")
        expect(first_household.reference_id).not_to eq(second_household.reference_id)
        expect(first_household.auth_token).not_to eq(second_household.auth_token)
      end
    end

    it "raises when the model has no fields configured and none are passed" do
      allow(invitation.class).to receive(:fields_to_redact).and_return(nil)

      expect { invitation.redact! }
        .to raise_error("No fields to redact in #{invitation.class}")
    end

    it "raises when the resolved field set is empty" do
      allow(invitation.class).to receive(:fields_to_redact).and_return({})

      expect { invitation.redact! }
        .to raise_error("No fields to redact in #{invitation.class}")
    end
  end
end
