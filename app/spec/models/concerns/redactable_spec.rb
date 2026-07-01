require "rails_helper"

RSpec.describe Redactable, type: :model do
  let(:invitation) { create(:cbv_flow_invitation) }

  describe "#redact!" do
    it "raises when the model has no fields configured and none are passed" do
      allow(invitation.class).to receive(:fields_to_redact).and_return(nil)

      expect { invitation.redact! }
        .to raise_error("No fields to redact in #{invitation.class} (or its superclass)")
    end

    it "raises when the resolved field set is empty" do
      allow(invitation.class).to receive(:fields_to_redact).and_return({})

      expect { invitation.redact! }
        .to raise_error("No fields to redact in #{invitation.class} (or its superclass)")
    end
  end
end
