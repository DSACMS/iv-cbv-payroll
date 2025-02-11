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
    context "when the user is authorized" do
      before do
        allow(Rails.application.config.client_agencies["ma"])
          .to receive(:authorized_emails).and_return(test_email)
      end

      it "creates a User object and logs in as them" do
        expect { post :ma_dta }
          .to change(User, :count)
          .by(1)

        new_user = User.last
        expect(new_user).to have_attributes(
          email: test_email,
          client_agency_id: "ma"
        )
        expect(controller.current_user).to eq(new_user)
      end

      it "tracks events" do
        expect_any_instance_of(MixpanelEventTracker).to receive(:track).with("CaseworkerLogin", anything, hash_including(
          client_agency_id: "ma",
          user_id: be_a(Integer)
        ))

        expect_any_instance_of(NewRelicEventTracker).to receive(:track).with("CaseworkerLogin", anything, hash_including(
          client_agency_id: "ma",
          user_id: be_a(Integer)
        ))

        post :ma_dta
      end

      context "when the user already has authenticated before" do
        let!(:existing_user) { create(:user, email: test_email, client_agency_id: "ma") }

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

      # Re-using the same email across multiple client agencies should be only
      # useful to us in development/demo.
      context "when the user already has a sandbox account" do
        let!(:existing_user) { create(:user, email: test_email, client_agency_id: "sandbox") }

        it "creates a new User for the ma_dta client agency" do
          expect { post :ma_dta }
            .to change(User, :count)
            .by(1)

          new_user = User.last
          expect(new_user).to have_attributes(
            email: test_email,
            client_agency_id: "ma"
          )
          expect(controller.current_user).to eq(new_user)
        end
      end
    end

    context "when the user is not authorized" do
      it "redirects to root url with an alert" do
        post :ma_dta
        expect(response).to redirect_to(root_url)
        expect(flash[:alert]).to be_present
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

    it "creates a User in the correct client agency and logs them in" do
      expect { post :nyc_dss }
        .to change(User, :count)
        .by(1)

      new_user = User.last
      expect(new_user).to have_attributes(
        email: test_email,
        client_agency_id: "nyc"
      )
      expect(controller.current_user).to eq(new_user)
    end
  end
end
