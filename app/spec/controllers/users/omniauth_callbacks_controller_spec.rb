require "rails_helper"

RSpec.describe Users::OmniauthCallbacksController do
  let(:test_email) { "test@example.com" }
  let(:valid_auth_info) do
    {
      "info" => {
        "email" => test_email
      }
    }
  end

  before do
    request.env["devise.mapping"] = Devise.mappings[:user]
    request.env["omniauth.auth"] = valid_auth_info
  end

  describe "#ma_dta" do
    it "creates a User object and logs in as them" do
      expect { post :ma_dta }
        .to change(User, :count)
        .by(1)

      new_user = User.last
      expect(new_user).to have_attributes(
        email: test_email,
        site_id: "ma"
      )
      expect(controller.current_user).to eq(new_user)
    end

    context "when the user already has authenticated before" do
      let!(:existing_user) { User.create(email: test_email, site_id: "ma") }

      it "logs the user into the existing User" do
        expect { post :ma_dta }
          .not_to change(User, :count)
        expect(controller.current_user).to eq(existing_user)
      end

      context "when the email address has a capital letter in it" do
        let(:test_email) { "FOO@example.com" }

        it "logs the user into the existing User" do
          expect { post :ma_dta }
            .not_to change(User, :count)
          expect(controller.current_user).to eq(existing_user)
        end
      end
    end

    # Re-using the same email across multiple sites should be only
    # useful to us in development/demo.
    context "when the user already has a sandbox account" do
      let!(:existing_user) { User.create(email: test_email, site_id: "sandbox") }

      it "creates a new User for the ma_dta site" do
        expect { post :ma_dta }
          .to change(User, :count)
          .by(1)

        new_user = User.last
        expect(new_user).to have_attributes(
          email: test_email,
          site_id: "ma"
        )
        expect(controller.current_user).to eq(new_user)
      end
    end
  end

  describe "#nyc_dss" do
    let(:test_email) { "test@example.com" }
    let(:valid_auth_info) do
      {
        "info" => {
          "email" => test_email
        }
      }
    end

    it "creates a User in the correct site and logs them in" do
      expect { post :nyc_dss }
        .to change(User, :count)
        .by(1)

      new_user = User.last
      expect(new_user).to have_attributes(
        email: test_email,
        site_id: "nyc"
      )
      expect(controller.current_user).to eq(new_user)
    end
  end
end
