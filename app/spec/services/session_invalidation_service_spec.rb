require "rails_helper"

RSpec.describe SessionInvalidationService do
  describe "#valid?" do
    let(:user) { create(:user) }
    let(:session_id) { "AAAAA" }
    let(:service) { described_class.new(user, session_id) }

    context "for a new User" do
      it "is true" do
        expect(service.valid?).to eq(true)
      end
    end

    context "for a nil User (if they try to log out twice)" do
      let(:user) { nil }

      it "is false" do
        expect(service.valid?).to eq(false)
      end
    end

    context "for a User with invalidated sessions" do
      let(:user) { create(:user, invalidated_session_ids: invalidated_session_ids) }
      let(:invalidated_session_ids) { { "BBBBB" => Time.now } }

      it "is true when the current session is not invalidated" do
        expect(service.valid?).to eq(true)
      end

      context "when the current session is invalid" do
        let(:invalidated_session_ids) { { "AAAAA" => Time.now.to_i } }
        it "is false" do
          expect(service.valid?).to eq(false)
        end
      end
    end
  end

  describe "#invalidate!" do
    let(:user) { create(:user) }
    let(:session_id) { "AAAAA" }
    let(:service) { described_class.new(user, session_id) }

    context "for a new User" do
      it "appends the current session to the hash" do
        service.invalidate!
        expect(user.reload.invalidated_session_ids).to match(
          "AAAAA" => be_a(Integer)
        )
      end
    end

    context "for a User with other invalidated sessions" do
      let(:user) { create(:user, invalidated_session_ids: invalidated_session_ids) }
      let(:invalidated_session_ids) { { "BBBBB" => Time.now.to_i } }

      it "appends the current session to the hash" do
        service.invalidate!
        expect(user.reload.invalidated_session_ids).to match(
          "AAAAA" => be_a(Integer),
          "BBBBB" => be_a(Integer)
        )
      end

      context "for a user with stale invalidated sessions" do
        let(:user) { create(:user, invalidated_session_ids: invalidated_session_ids) }
        let(:invalidated_session_ids) { { "BBBBB" => (Time.now - 45.minutes).to_i } }

        it "removes those from the hash" do
          service.invalidate!
          expect(user.invalidated_session_ids).not_to include("BBBBB")
        end
      end
    end

    context "when the user has already logged out" do
      let(:user) { nil }

      it "does nothing" do
        expect { service.invalidate! }.not_to raise_error
      end
    end
  end
end
