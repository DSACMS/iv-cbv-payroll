require "rails_helper"

RSpec.describe "NSC education event tracking", :js, type: :feature do
  include E2e::TestHelpers
  include_context "activity_hub"

  let(:invitation) { create(:activity_flow_invitation) }
  let(:flow) { invitation.activity_flows.order(:created_at).last }

  before do
    allow(Rails.application.config).to receive(:is_internal_environment).and_return(true)
    allow(EventTrackingJob).to receive(:perform_later)
    allow(NscSynchronizationJob).to receive(:perform_later) { |id| NscSynchronizationJob.perform_now(id) }
    visit activities_flow_start_path(token: invitation.auth_token, reporting_window_months: 1)
    verify_page(page, title: I18n.t("activities.entries.show.title", benefit: I18n.t("shared.benefit.sandbox")))
    click_link I18n.t("activities.entries.show.continue")
    verify_page(page, title: I18n.t("activities.hub.title"))
  end

  it "tracks a validated NSC journey and navigation through the shared event pipeline" do
    flow.update!(identity: create(:identity, first_name: "Dedupe", last_name: "Testuser", date_of_birth: Date.new(1990, 1, 1)))
    visit verify_activities_flow_education_index_path(education_type: "college_or_university")
    verify_page(page, title: I18n.t("activities.education.verify.header"))
    click_link I18n.t("activities.activity_header_component.back")
    verify_page(page, title: I18n.t("activities.education.add_your_education.show.header"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationAddYourEducationViewed, anything,
      hash_excluding(:education_flow, :education_data_source, :education_type, :education_activity_id))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationBackClicked, anything,
      hash_including(cbv_flow_id: flow.id))

    visit verify_activities_flow_education_index_path(education_type: "college_or_university")
    verify_page(page, title: I18n.t("activities.education.verify.header"))
    click_button I18n.t("activities.education.verify.continue")
    verify_page(page, title: I18n.t("activities.education.edit.header"), wait: 10)
    activity = flow.education_activities.last
    expect(activity).to be_validated
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationFlowStarted, anything,
      hash_including(education_activity_id: activity.id, education_data_source: "pending"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil,
      hash_including(education_activity_id: activity.id, outcome: "validated"))

    click_link I18n.t("activities.activity_header_component.exit"), exact: true
    within("#exit-confirmation-modal") do
      click_button I18n.t("activities.activity_header_component.modal.back_button")
    end
    expect(page).to have_no_selector("#exit-confirmation-modal", visible: true)
    click_link I18n.t("activities.activity_header_component.exit"), exact: true
    within("#exit-confirmation-modal") do
      click_link I18n.t("activities.activity_header_component.modal.exit_link")
    end
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationExitClicked, anything,
      hash_including(cbv_flow_id: flow.id, modal_shown: true)).twice
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationExitModalCancelled, anything,
      hash_including(cbv_flow_id: flow.id))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationExitModalConfirmed, anything,
      hash_including(cbv_flow_id: flow.id))

    visit edit_activities_flow_education_path(id: activity)
    verify_page(page, title: I18n.t("activities.education.edit.header"))
    click_button I18n.t("activities.education.edit.continue")
    verify_page(page, title: I18n.t("activities.summary.title"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationFlowCompleted, anything,
      hash_including(education_activity_id: activity.id, education_data_source: "validated")).once
  end

  it "distinguishes partially self-attested enrollment, credit hours, uploads, review, and completion" do
    flow.update!(identity: create(:identity, first_name: "Ziggy", last_name: "Testuser", date_of_birth: Date.new(1992, 7, 19)))
    visit verify_activities_flow_education_index_path(education_type: "college_or_university")
    verify_page(page, title: I18n.t("activities.education.verify.header"))
    click_button I18n.t("activities.education.verify.continue")
    verify_page(page, title: I18n.t("activities.education.edit.header"), wait: 10)
    activity = flow.education_activities.last
    expect(activity).to be_partially_self_attested
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationNscLookupCompleted, nil,
      hash_including(outcome: "partial_data", education_data_source: "partially_self_attested"))

    click_button I18n.t("activities.education.edit.continue")
    verify_page(page, title: I18n.t("activities.education.term_credit_hours.heading", school_name: "Sunrise Community College"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationTermCreditHoursViewed, anything,
      hash_including(education_activity_id: activity.id, education_data_source: "partially_self_attested"))
    fill_in "nsc_enrollment_term_credit_hours", with: "3"
    click_button I18n.t("activities.education.term_credit_hours.continue")
    verify_page(page, title: I18n.t("activities.document_uploads.new.title", name: "Sunrise Community College"), skip_axe_rules: %w[heading-order])
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationDocumentUploadViewed, anything,
      hash_including(education_data_source: "partially_self_attested"))
    click_button I18n.t("activities.document_uploads.new.continue")
    verify_page(page, title: I18n.t("activities.education.review.title", school_name: "Sunrise Community College"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationReviewViewed, anything,
      hash_including(education_data_source: "partially_self_attested"))
    click_button I18n.t("activities.education.review.save")
    verify_page(page, title: I18n.t("activities.hub.title"))
    expect(EventTrackingJob).to have_received(:perform_later).with(TrackEvent::EducationFlowCompleted, anything,
      hash_including(education_activity_id: activity.id, education_data_source: "partially_self_attested")).once
  end
end
