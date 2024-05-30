# frozen_string_literal: true

require "rails_helper"

RSpec.describe CloudGovConfig, type: :model do
  subject { described_class }

  describe ".dig" do
    context "VCAP_SERVICES is blank" do
      it "returns nil" do
        expect(subject.dig(:s3, :credentials, :bucket)).to be_nil
      end
    end

    context "VCAP_SERVICES is set" do
      let(:bucket_name) { "bucket-name" }
      let(:vcap) {
        {
          s3: [
            {
              credentials: {
                bucket: bucket_name
              }
            }
          ]
        }
      }

      around do |example|
        ClimateControl.modify VCAP_SERVICES: vcap.to_json do
          example.run
        end
      end

      it "can find a path" do
        expect(subject.dig(:s3, :credentials, :bucket)).to eq bucket_name
      end

      it "returns nil for a missing path" do
        expect(subject.dig(:s3, :missing)).to be_nil
      end

      it "returns nil for a missing service" do
        expect(subject.dig(:rds, :credentials)).to be_nil
      end
    end
  end
end
