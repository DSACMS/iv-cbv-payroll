require "rails_helper"

RSpec.describe Activities::SuccessController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) { create(:activity_flow) }

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  describe "GET #show" do
    context "with a named applicant in a tokenized flow" do
      let(:applicant) { create(:cbv_applicant, first_name: "Lisa", last_name: "Williams") }
      let(:invitation) { create(:activity_flow_invitation, cbv_applicant: applicant) }
      let(:activity_flow) { create(:activity_flow, cbv_applicant: applicant, activity_flow_invitation: invitation, completed_at: Time.current) }
      let(:reporting_for_text) {
        I18n.t("activities.reporting_for.text_html", name: "#{applicant.first_name} #{applicant.last_name}")
      }

      before { get :show }

      it "does not display the reporting banner" do
        expect(response).to have_http_status(:ok)
        expect(Capybara.string(response.body)).to have_no_text(reporting_for_text)
      end
    end

    it "redirects to summary if the flow has not been submitted" do
      get :show

      expect(response).to redirect_to(activities_flow_summary_path)
    end

    context "with a submitted tokenized flow" do
      let(:client_agency_id) { "sandbox" }
      let(:applicant) { create(:cbv_applicant, client_agency_id: client_agency_id) }
      let(:employment_focused) { false }
      let(:unpaid_work_only) { false }
      let(:invitation) do
        create(:activity_flow_invitation, cbv_applicant: applicant, client_agency_id: client_agency_id,
          employment_focused: employment_focused, unpaid_work_only: unpaid_work_only)
      end
      let(:activity_flow) do
        create(:activity_flow, cbv_applicant: applicant, activity_flow_invitation: invitation,
          employment_focused: employment_focused, unpaid_work_only: unpaid_work_only,
          completed_at: Time.current, confirmation_code: "SANDBOX123",
          volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
      end
      let(:agency_name) { I18n.t("shared.agency_full_name.#{client_agency_id}") }
      let(:agency_config) { Rails.application.config.client_agencies[client_agency_id] }
      let(:rendered) { Capybara.string(response.body) }

      context "with community engagement" do
        let(:renewal_instructions) { I18n.t("activities.success.show.head_of_household_description_html", agency_website: agency_config.agency_contact_website) }
        let(:agency_website_link_text) { Capybara.string(renewal_instructions).find("a").text }

        before { get :show }

        it "shows the submitted community engagement activities heading" do
          expect(response).to have_http_status(:ok)
          expect(rendered).to have_selector("h1", text: I18n.t("activities.success.show.title", agency_name: agency_name))
        end

        it "shows the confirmation code" do
          confirmation = I18n.t("activities.success.show.confirmation_code_html", confirmation_code: activity_flow.confirmation_code)

          expect(rendered).to have_text(Capybara.string(confirmation).text)
        end

        it "shows the agency review next step" do
          expect(rendered).to have_selector("p", text: I18n.t("activities.success.show.next_steps_description", agency_name: agency_name), exact_text: true, normalize_ws: true)
        end

        it "shows the report download step" do
          expect(rendered).to have_selector("h3", text: I18n.t("activities.success.show.whats_next_1_title"))
          expect(rendered).to have_text(I18n.t("activities.success.show.whats_next_1_li_1"))
          expect(rendered).to have_link(I18n.t("activities.success.show.download_pdf"), href: activities_flow_submit_path(format: :pdf))
        end

        it "opens the outlined report download in a new tab" do
          download_link = rendered.find_link(I18n.t("activities.success.show.download_pdf"))

          expect(download_link[:class]).to include("usa-button--outline")
          expect(download_link[:target]).to eq("_blank")
          expect(download_link[:rel]).to eq("noopener noreferrer")
        end

        it "shows renewal instructions with the agency website" do
          expect(rendered).to have_selector("h3", text: I18n.t("activities.success.show.head_of_household_title"))
          expect(rendered).to have_selector("p", text: Capybara.string(renewal_instructions).text, exact_text: true, normalize_ws: true)
          expect(rendered).to have_link(agency_website_link_text, href: agency_config.agency_contact_website)
        end

        it "shows the household member next step" do
          expect(rendered).to have_selector("h3", text: I18n.t("activities.success.show.household_member_title"))
          expect(rendered).to have_text(I18n.t("activities.success.show.household_member_description", agency_name: agency_name))
        end

        it "links to the survey" do
          expect(rendered).to have_link(I18n.t("activities.success.show.survey"), href: feedbacks_path(form: "survey", referer: activities_flow_success_url))
        end

        context "with another agency" do
          let(:client_agency_id) { "nh_dhhs" }

          it "uses that agency's name and website" do
            expect(rendered).to have_selector("h1", text: I18n.t("activities.success.show.title", agency_name: agency_name))
            expect(rendered).to have_text(I18n.t("activities.success.show.household_member_description", agency_name: agency_name))
            expect(rendered).to have_link(agency_website_link_text, href: agency_config.agency_contact_website)
          end
        end

        context "with unpaid work only" do
          let(:unpaid_work_only) { true }

          it "shows the community engagement heading and next steps" do
            expect(rendered).to have_selector("h1", text: I18n.t("activities.success.show.title", agency_name: agency_name))
            expect(rendered).to have_selector("h3", text: I18n.t("activities.success.show.head_of_household_title"))
            expect(rendered).to have_text(I18n.t("activities.success.show.household_member_description", agency_name: agency_name))
            expect(rendered).to have_link(agency_website_link_text, href: agency_config.agency_contact_website)
          end
        end
      end

      context "with employment-focused work" do
        let(:employment_focused) { true }
        let(:compensation_type) { :paid }

        before do
          create(:employment_activity, activity_flow: activity_flow, compensation_type: compensation_type)
          get :show
        end

        it "shows the submitted jobs heading and processing message" do
          expect(rendered).to have_selector("h1", text: I18n.t("activities.success.show.employment_focused.title", agency_name: agency_name))
          expect(rendered).to have_text(I18n.t("activities.success.show.employment_focused.subheading"))
        end

        it "shows the employment next steps" do
          expect(rendered).to have_selector("p", text: I18n.t("activities.success.show.employment_focused.whats_next.subheading", agency_name: agency_name), exact_text: true, normalize_ws: true)
          expect(rendered).to have_selector("h3", text: I18n.t("activities.success.show.employment_focused.whats_next.download_your_report.heading"))
          expect(rendered).to have_text(I18n.t("activities.success.show.employment_focused.whats_next.head_of_household.subheading"))
          expect(rendered).to have_text(I18n.t("activities.success.show.employment_focused.whats_next.household_member.subheading", agency_name: agency_name))
        end

        it "opens the outlined report download in a new tab" do
          download_link = rendered.find_link(I18n.t("activities.success.show.download_pdf"))

          expect(download_link[:href]).to eq(activities_flow_submit_path(format: :pdf))
          expect(download_link[:class]).to include("usa-button--outline")
          expect(download_link[:target]).to eq("_blank")
          expect(download_link[:rel]).to eq("noopener noreferrer")
        end

        context "with in-kind work" do
          let(:compensation_type) { :unpaid_or_in_kind }

          it "shows the employment heading and renewal instructions" do
            expect(rendered).to have_selector("h1", text: I18n.t("activities.success.show.employment_focused.title", agency_name: agency_name))
            expect(rendered).to have_text(I18n.t("activities.success.show.employment_focused.subheading"))
            expect(rendered).to have_text(I18n.t("activities.success.show.employment_focused.whats_next.head_of_household.subheading"))
          end
        end
      end
    end
  end
end
