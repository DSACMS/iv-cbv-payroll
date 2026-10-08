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
