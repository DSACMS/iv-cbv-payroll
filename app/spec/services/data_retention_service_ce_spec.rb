require "rails_helper"
require "rake"

RSpec.describe DataRetentionService do
  let(:service) { described_class.new }
  let(:now) { Time.zone.local(2026, 10, 19, 12) }
  let(:invitation) { nil }
  let!(:flow) do
    create(:activity_flow,
      activity_flow_invitation: invitation,
      cbv_applicant: invitation&.cbv_applicant || create(:cbv_applicant),
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      with_identity: true,
      argyle_user_id: "example-user",
      additional_information: { "name" => "Example Person" },
      updated_at: 8.days.ago)
  end
  let!(:education) { create(:education_activity, activity_flow: flow, **contact_fields, school_name: "Example School", contact_title: "Advisor") }
  let!(:employment) { create(:employment_activity, activity_flow: flow, **contact_fields) }
  let!(:training) { create(:job_training_activity, activity_flow: flow, **contact_fields, program_name: "Example Program", organization_address: "Example Address") }
  let!(:volunteering) do
    create(:volunteering_activity, activity_flow: flow, **address_fields,
      coordinator_name: "Example Coordinator", coordinator_email: "example@example.com",
      coordinator_phone_number: "555-555-0100", additional_comments: "Example comment")
  end
  let!(:term) { create(:nsc_enrollment_term, education_activity: education, middle_name: "Example") }
  let!(:month) { create(:employment_activity_month, employment_activity: employment) }
  let(:address_fields) do
    { street_address: "123 Example St", street_address_line_2: "Unit 1", city: "Example City", state: "CA", zip_code: "90001" }
  end
  let(:contact_fields) do
    address_fields.merge(contact_name: "Example Contact", contact_email: "example@example.com", contact_phone_number: "555-555-0100", additional_comments: "Example comment")
  end
  let(:redacted_address) do
    { street_address: "REDACTED", street_address_line_2: "REDACTED", city: "REDACTED", state: "REDACTED", zip_code: "REDACTED" }
  end
  let(:redacted_contact) do
    redacted_address.merge(contact_name: "REDACTED", contact_email: "REDACTED@example.com", contact_phone_number: "REDACTED", additional_comments: "REDACTED")
  end

  around do |example|
    Timecop.freeze(now, &example)
  end

  def expect_redacted(record, **attributes)
    expect(record.reload).to have_attributes(**attributes, redacted_at: now)
  end

  describe "#redact_incomplete_activity_flows" do
    context "with persisted payroll summaries" do
      let!(:payroll_account) { create(:payroll_account, flow: flow) }
      let!(:summary) { create(:activity_flow_monthly_summary, activity_flow: flow, payroll_account: payroll_account, total_w2_hours: 40) }
      let!(:employment_summary) { create(:activity_flow_employment_summary, activity_flow: flow, payroll_account: payroll_account, employer_name: "Example Employer") }

      it "preserves the inactivity timestamp during flow redaction" do
        expect { service.redact_incomplete_activity_flows }.not_to change { flow.reload.updated_at }
        expect_redacted(flow)
      end

      it "keeps summaries eligible when flow redaction runs first" do
        service.redact_incomplete_activity_flows
        service.redact_activity_flow_summaries

        expect_redacted(summary, total_w2_hours: 0)
        expect_redacted(employment_summary, employer_name: "REDACTED")
        expect_redacted(payroll_account)
      end
    end

    it "redacts an inactive standalone flow and its related records" do
      service.redact_incomplete_activity_flows

      expect_redacted(flow, end_user_id: "00000000-0000-0000-0000-000000000000")
      expect_redacted(flow.identity, first_name: start_with("REDACTED-"))
      expect_redacted(education, school_name: "REDACTED")
      expect_redacted(employment, employer_name: "REDACTED")
      expect_redacted(training, organization_name: "REDACTED")
      expect_redacted(volunteering, organization_name: "REDACTED")
      expect_redacted(term, first_name: "REDACTED")
      expect_redacted(month, gross_income: 0)
    end

    context "before the inactivity threshold" do
      before { flow.update_columns(updated_at: 7.days.ago + 1.minute) }

      it "preserves the flow and its related records" do
        expect { service.redact_incomplete_activity_flows }
          .not_to change { [ flow, flow.identity, education, employment, training, volunteering, term, month ].map { |record| record.reload.attributes } }
      end
    end

    context "at the inactivity threshold" do
      before { flow.update_columns(updated_at: 7.days.ago) }

      it "waits until the threshold has passed" do
        expect { service.redact_incomplete_activity_flows }.not_to change { flow.reload.attributes }
      end
    end

    context "with an invitation" do
      let(:invitation) { create(:activity_flow_invitation, expires_at: 8.days.ago) }
      let!(:member) { create(:household_member, activity_flow_invitation: invitation) }

      it "redacts the invitation, flow, and related records after the expiration grace period" do
        service.redact_all!

        expect_redacted(flow)
        expect_redacted(invitation)
        expect_redacted(member)
        expect_redacted(member.household)
        expect_redacted(flow.identity)
        expect_redacted(flow.cbv_applicant)
        expect_redacted(education)
        expect_redacted(employment)
        expect_redacted(training)
        expect_redacted(volunteering)
        expect_redacted(term)
        expect_redacted(month)
      end

      context "before the expiration grace period ends" do
        before do
          invitation.update!(expires_at: 7.days.ago + 1.minute)
          flow.update_columns(updated_at: 1.year.ago)
        end

        it "preserves the flow regardless of its inactivity" do
          expect { service.redact_all! }
            .not_to change { [ flow, flow.identity, education, employment, training, volunteering, term, month, invitation, member, member.household ].map { |record| record.reload.attributes } }
        end
      end

      context "at the expiration threshold" do
        before { invitation.update!(expires_at: 7.days.ago) }

        it "waits until the threshold has passed" do
          expect { service.redact_all! }
            .not_to change { [ flow, invitation, member, member.household ].map { |record| record.reload.attributes } }
        end
      end

      context "when the flow was recently updated" do
        before { flow.update_columns(updated_at: now) }

        it "uses the invitation deadline rather than flow inactivity" do
          service.redact_incomplete_activity_flows

          expect_redacted(flow)
          expect_redacted(invitation)
          expect_redacted(member)
          expect_redacted(member.household)
        end
      end

      context "when the invitation is already redacted" do
        before { invitation.redact! }

        it "still redacts the incomplete flow and its household records" do
          service.redact_incomplete_activity_flows

          expect_redacted(flow)
          expect_redacted(member)
          expect_redacted(member.household)
        end
      end

      context "when the invitation has no expiration" do
        before { invitation.update_columns(expires_at: nil) }

        it "preserves records without a known retention deadline" do
          expect { service.redact_all! }
            .not_to change { [ flow, invitation, member, member.household ].map { |record| record.reload.attributes } }
        end
      end

      context "when multiple incomplete flows share the invitation and identity" do
        let!(:other_flow) do
          create(:activity_flow, activity_flow_invitation: invitation,
            cbv_applicant: flow.cbv_applicant, identity: flow.identity,
            volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
        end

        it "redacts every flow before scrubbing the shared records" do
          service.redact_incomplete_activity_flows

          expect_redacted(flow)
          expect_redacted(other_flow)
          expect_redacted(flow.identity)
          expect_redacted(flow.cbv_applicant)
          expect_redacted(member)
          expect_redacted(member.household)
        end
      end

      context "when a submitted flow shares the invitation and identity" do
        let!(:submitted_flow) do
          create(:activity_flow, activity_flow_invitation: invitation,
            cbv_applicant: flow.cbv_applicant, identity: flow.identity, completed_at: 1.day.ago,
            volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
        end

        it "preserves shared records until the submitted flow is eligible" do
          service.redact_all!

          expect_redacted(flow)
          expect_redacted(invitation)
          expect(submitted_flow.reload.redacted_at).to be_nil
          expect(flow.identity.reload.redacted_at).to be_nil
          expect(flow.cbv_applicant.reload.redacted_at).to be_nil
          expect(member.reload.redacted_at).to be_nil
          expect(member.household.reload.redacted_at).to be_nil
        end

        it "redacts shared records when the last flow is eligible" do
          service.redact_all!
          submitted_flow.update_columns(transmitted_at: 8.days.ago)
          service.redact_all!

          expect_redacted(submitted_flow)
          expect_redacted(flow.identity)
          expect_redacted(flow.cbv_applicant)
          expect_redacted(member)
          expect_redacted(member.household)
        end
      end

      it "does not repeat redaction" do
        service.redact_all!

        expect { service.redact_all! }
          .not_to change { [ flow, invitation, member, member.household, flow.identity, education, employment, training, volunteering, term, month ].map { |record| record.reload.attributes } }
      end
    end

    context "with a completed flow awaiting transmission" do
      before { flow.update_columns(completed_at: 8.days.ago) }

      it "preserves the flow" do
        expect { service.redact_incomplete_activity_flows }.not_to change { flow.reload.attributes }
      end
    end

    it "does not repeat redaction" do
      service.redact_incomplete_activity_flows

      expect { service.redact_incomplete_activity_flows }
        .not_to change { [ flow, flow.identity, education, employment, training, volunteering, term, month ].map { |record| record.reload.attributes } }
    end
  end

  describe "#redact_complete_activity_flows" do
    before { flow.update_columns(completed_at: 9.days.ago, transmitted_at: 8.days.ago, confirmation_code: "EXAMPLE123") }

    it "scrubs the approved flow fields" do
      service.redact_complete_activity_flows

      expect_redacted(flow,
        argyle_user_id: "REDACTED", device_id: "00000000-0000-0000-0000-000000000000",
        end_user_id: "00000000-0000-0000-0000-000000000000", additional_information: {}, confirmation_code: "REDACTED")
    end

    it "scrubs identity fields" do
      service.redact_complete_activity_flows

      expect_redacted(flow.identity, first_name: start_with("REDACTED-"), last_name: "REDACTED", date_of_birth: Date.new(1990, 1, 1))
    end

    it "scrubs education fields" do
      service.redact_complete_activity_flows

      expect_redacted(education, **redacted_contact, school_name: "REDACTED", contact_title: "REDACTED")
    end

    it "scrubs employment fields" do
      service.redact_complete_activity_flows

      expect_redacted(employment, **redacted_contact, employer_name: "REDACTED")
    end

    it "scrubs job training fields" do
      service.redact_complete_activity_flows

      expect_redacted(training, **redacted_contact, organization_name: "REDACTED", program_name: "REDACTED", organization_address: "REDACTED")
    end

    it "scrubs volunteering fields" do
      service.redact_complete_activity_flows

      expect_redacted(volunteering, **redacted_address, organization_name: "REDACTED",
        coordinator_name: "REDACTED", coordinator_email: "REDACTED@example.com", coordinator_phone_number: "REDACTED", additional_comments: "REDACTED")
    end

    it "scrubs enrollment term fields" do
      service.redact_complete_activity_flows

      expect_redacted(term, first_name: "REDACTED", last_name: "REDACTED", middle_name: "REDACTED", school_name: "REDACTED")
    end

    it "scrubs gross income and retains structural month data" do
      service.redact_complete_activity_flows

      expect_redacted(month, gross_income: 0, hours: 20, month: flow.reporting_months.first.beginning_of_month)
    end

    context "before the transmission threshold" do
      before { flow.update_columns(transmitted_at: 7.days.ago + 1.minute) }

      it "preserves the flow and its related records" do
        expect { service.redact_complete_activity_flows }
          .not_to change { [ flow, flow.identity, education, employment, training, volunteering, term, month ].map { |record| record.reload.attributes } }
      end
    end

    context "at the transmission threshold" do
      before { flow.update_columns(transmitted_at: 7.days.ago) }

      it "waits until the threshold has passed" do
        expect { service.redact_complete_activity_flows }.not_to change { flow.reload.attributes }
      end
    end

    context "without transmission" do
      before { flow.update_columns(transmitted_at: nil) }

      it "preserves the completed flow" do
        expect { service.redact_all! }.not_to change { flow.reload.attributes }
      end
    end

    context "with an invitation" do
      let(:invitation) { create(:activity_flow_invitation, cbv_applicant: flow_applicant) }
      let(:flow_applicant) { create(:cbv_applicant) }

      it "keeps the invitation and applicant available while the invitation is valid" do
        service.redact_complete_activity_flows

        expect_redacted(flow)
        expect(invitation.reload.redacted_at).to be_nil
        expect(flow_applicant.reload.redacted_at).to be_nil
      end

      context "when the invitation has expired but is still within its retention window" do
        before { invitation.update!(expires_at: 1.day.ago) }

        it "redacts the applicant without prematurely redacting the invitation" do
          service.redact_complete_activity_flows

          expect_redacted(flow)
          expect_redacted(flow_applicant)
          expect(invitation.reload.redacted_at).to be_nil
        end
      end
    end

    context "with another flow sharing the identity and applicant" do
      let!(:active_flow) do
        create(:activity_flow, identity: flow.identity, cbv_applicant: flow.cbv_applicant,
          volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
      end

      it "preserves shared data while the other flow is active" do
        service.redact_complete_activity_flows

        expect_redacted(flow)
        expect(active_flow.reload.redacted_at).to be_nil
        expect(flow.identity.reload.redacted_at).to be_nil
        expect(flow.cbv_applicant.reload.redacted_at).to be_nil
      end

      it "redacts shared data once the last flow becomes eligible" do
        active_flow.update_columns(completed_at: 9.days.ago, transmitted_at: 8.days.ago)
        service.redact_complete_activity_flows

        expect_redacted(flow.identity)
        expect_redacted(flow.cbv_applicant)
      end
    end

    it "does not repeat redaction" do
      service.redact_complete_activity_flows

      expect { service.redact_complete_activity_flows }
        .not_to change { [ flow, flow.identity, education, employment, training, volunteering, term, month ].map { |record| record.reload.attributes } }
    end

    context "with draft activities" do
      before do
        education.update_columns(draft: true)
        employment.update_columns(draft: true)
        training.update_columns(draft: true)
        volunteering.update_columns(draft: true)
      end

      it "redacts drafts as well as published activities" do
        service.redact_complete_activity_flows

        expect_redacted(education)
        expect_redacted(employment)
        expect_redacted(training)
        expect_redacted(volunteering)
      end
    end

    context "through the data_deletion:redact_all task" do
      let!(:payroll_account) { create(:payroll_account, flow: flow) }
      let!(:summary) { create(:activity_flow_monthly_summary, activity_flow: flow, payroll_account: payroll_account, total_w2_hours: 40) }
      let!(:employment_summary) { create(:activity_flow_employment_summary, activity_flow: flow, payroll_account: payroll_account, employer_name: "Example Employer") }

      around do |example|
        original_rake_application = Rake.application
        Rake.application = Rake::Application.new
        load Rails.root.join("lib/tasks/data_deletion.rake")
        Rake::Task.define_task(:environment)
        example.run
      ensure
        Rake.application = original_rake_application
      end

      it "redacts CE records alongside the existing summaries and payroll accounts" do
        Rake::Task["data_deletion:redact_all"].invoke

        expect_redacted(flow)
        expect_redacted(term)
        expect_redacted(month)
        expect_redacted(summary, total_w2_hours: 0)
        expect_redacted(employment_summary, employer_name: "REDACTED")
        expect_redacted(payroll_account)
      end

      context "with an expired household invitation" do
        let(:invitation) { create(:activity_flow_invitation, expires_at: 8.days.ago, reference_id: "Example reference") }
        let!(:member) { create(:household_member, activity_flow_invitation: invitation) }

        it "redacts the full CE record set through the rake task" do
          Rake::Task["data_deletion:redact_all"].invoke

          expect_redacted(invitation, reference_id: "REDACTED")
          expect_redacted(flow)
          expect_redacted(flow.cbv_applicant)
          expect_redacted(flow.identity)
          expect_redacted(member, display_name: "REDACTED")
          expect_redacted(member.household)
          expect_redacted(education)
          expect_redacted(employment)
          expect_redacted(training)
          expect_redacted(volunteering)
          expect_redacted(term)
          expect_redacted(month)
          expect_redacted(summary)
          expect_redacted(employment_summary)
        end
      end
    end
  end

  describe ".manually_redact_by_case_number!" do
    let(:invitation) { create(:activity_flow_invitation, reference_id: "example-reference") }
    let!(:member) { create(:household_member, activity_flow_invitation: invitation) }
    let(:household) { member.household }
    let!(:unused_invitation) { create(:activity_flow_invitation, cbv_applicant: flow.cbv_applicant, reference_id: "unused-reference") }
    let!(:unused_member) { create(:household_member, household: household, activity_flow_invitation: unused_invitation) }
    let(:case_number) { "EXAMPLE-CASE" }

    before { flow.cbv_applicant.update!(case_number: case_number) }

    it "redacts the entire CE record set, including invitations without an applicant or a flow" do
      described_class.manually_redact_by_case_number!(case_number)

      expect_redacted(flow)
      expect_redacted(flow.cbv_applicant)
      expect_redacted(flow.identity)
      expect_redacted(invitation, auth_token: start_with("REDACTED-"), reference_id: "REDACTED")
      expect_redacted(unused_invitation, auth_token: start_with("REDACTED-"), reference_id: "REDACTED")
      expect_redacted(member, display_name: "REDACTED", reference_id: start_with("REDACTED-"))
      expect_redacted(unused_member, display_name: "REDACTED", reference_id: start_with("REDACTED-"))
      expect_redacted(household, auth_token: start_with("REDACTED-"), reference_id: start_with("REDACTED-"))
      expect_redacted(education)
      expect_redacted(employment)
      expect_redacted(training)
      expect_redacted(volunteering)
      expect_redacted(term)
      expect_redacted(month)
    end

    context "with an unused invitation and no CE flow" do
      before do
        flow.destroy!
        unused_member.update!(household: create(:household))
      end

      it "still redacts the unused invitation and its household member" do
        described_class.manually_redact_by_case_number!(case_number)

        expect_redacted(unused_invitation)
        expect_redacted(unused_member)
        expect_redacted(unused_member.household)
      end
    end

    context "with an unrelated active household member" do
      let!(:other_member) { create(:household_member, household: household) }

      it "preserves the other member and shared household" do
        described_class.manually_redact_by_case_number!(case_number)

        expect_redacted(member)
        expect(other_member.reload.redacted_at).to be_nil
        expect(other_member.activity_flow_invitation.reload.redacted_at).to be_nil
        expect(household.reload.redacted_at).to be_nil
      end
    end
  end

  describe "#redact_activity_invitations" do
    let(:invitation_applicant) { create(:cbv_applicant) }
    let!(:unused_invitation) do
      create(:activity_flow_invitation, cbv_applicant: invitation_applicant,
        expires_at: 8.days.ago, reference_id: "Example reference")
    end
    let!(:member) { create(:household_member, activity_flow_invitation: unused_invitation) }
    let(:household) { member.household }

    it "scrubs the invitation and its household records after the expiration grace period" do
      service.redact_activity_invitations

      expect_redacted(unused_invitation, reference_id: "REDACTED", auth_token: start_with("REDACTED-"))
      expect_redacted(invitation_applicant, first_name: "REDACTED")
      expect_redacted(member, display_name: "REDACTED", reference_id: start_with("REDACTED-"))
      expect_redacted(household, auth_token: start_with("REDACTED-"), reference_id: start_with("REDACTED-"))
    end

    context "before the expiration threshold" do
      before { unused_invitation.update!(expires_at: 7.days.ago + 1.minute) }

      it "preserves the invitation and its related records" do
        expect { service.redact_activity_invitations }
          .not_to change { [ unused_invitation, invitation_applicant, member, household ].map { |record| record.reload.attributes } }
      end
    end

    context "at the expiration threshold" do
      before { unused_invitation.update!(expires_at: 7.days.ago) }

      it "waits until the threshold has passed" do
        expect { service.redact_activity_invitations }
          .not_to change { [ unused_invitation, invitation_applicant, member, household ].map { |record| record.reload.attributes } }
      end
    end

    context "with an active invitation" do
      before { unused_invitation.update!(expires_at: 1.day.from_now) }

      it "preserves the invitation and its related records" do
        expect { service.redact_activity_invitations }
          .not_to change { [ unused_invitation, invitation_applicant, member, household ].map { |record| record.reload.attributes } }
      end
    end

    context "without an expiration" do
      before { unused_invitation.update_columns(expires_at: nil) }

      it "preserves records without a known retention deadline" do
        expect { service.redact_activity_invitations }
          .not_to change { [ unused_invitation, invitation_applicant, member, household ].map { |record| record.reload.attributes } }
      end
    end

    context "with another active CE invitation for the applicant" do
      let!(:active_invitation) { create(:activity_flow_invitation, cbv_applicant: invitation_applicant) }

      it "preserves the shared applicant" do
        service.redact_activity_invitations

        expect_redacted(unused_invitation)
        expect(active_invitation.reload.redacted_at).to be_nil
        expect(invitation_applicant.reload.redacted_at).to be_nil
      end
    end

    context "with an active Income invitation for the applicant" do
      let!(:active_invitation) { create(:cbv_flow_invitation, cbv_applicant: invitation_applicant) }

      it "preserves the shared applicant" do
        service.redact_activity_invitations

        expect_redacted(unused_invitation)
        expect(active_invitation.reload.redacted_at).to be_nil
        expect(invitation_applicant.reload.redacted_at).to be_nil
      end
    end

    context "with an active Income flow for the applicant" do
      let!(:active_flow) { create(:cbv_flow, cbv_applicant: invitation_applicant, cbv_flow_invitation: nil) }

      it "preserves the shared applicant" do
        service.redact_activity_invitations

        expect_redacted(unused_invitation)
        expect(active_flow.reload.redacted_at).to be_nil
        expect(invitation_applicant.reload.redacted_at).to be_nil
      end
    end

    context "with a submitted CE flow awaiting transmission" do
      let!(:submitted_flow) do
        create(:activity_flow, cbv_applicant: invitation_applicant, activity_flow_invitation: unused_invitation,
          completed_at: 1.day.ago, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0)
      end

      it "preserves the flow, applicant, and household records" do
        service.redact_all!

        expect_redacted(unused_invitation)
        expect(submitted_flow.reload.redacted_at).to be_nil
        expect(invitation_applicant.reload.redacted_at).to be_nil
        expect(member.reload.redacted_at).to be_nil
        expect(household.reload.redacted_at).to be_nil
      end
    end

    context "with another active household member" do
      let!(:other_member) { create(:household_member, household: household) }

      it "preserves the shared household" do
        service.redact_activity_invitations

        expect_redacted(member)
        expect(other_member.reload.redacted_at).to be_nil
        expect(household.reload.redacted_at).to be_nil
      end

      it "redacts the household after the last member becomes eligible" do
        service.redact_activity_invitations
        other_member.activity_flow_invitation.update!(expires_at: 8.days.ago)
        service.redact_activity_invitations

        expect_redacted(other_member)
        expect_redacted(household)
      end
    end

    it "does not repeat redaction" do
      service.redact_activity_invitations

      expect { service.redact_activity_invitations }
        .not_to change { [ unused_invitation, invitation_applicant, member, household ].map { |record| record.reload.attributes } }
    end

    it "is included in scheduled redaction" do
      service.redact_all!

      expect_redacted(unused_invitation)
      expect_redacted(member)
      expect_redacted(household)
    end
  end

  describe "shared applicant protection for Income retention" do
    let!(:income_flow) { create(:cbv_flow, cbv_applicant: flow.cbv_applicant, cbv_flow_invitation: nil, updated_at: 8.days.ago) }

    before { flow.update_columns(updated_at: now) }

    it "preserves the applicant while a CE flow is active" do
      service.redact_incomplete_cbv_flows

      expect_redacted(income_flow)
      expect(flow.cbv_applicant.reload.redacted_at).to be_nil
    end

    context "with an active CE invitation but no CE flow" do
      let!(:active_invitation) { create(:activity_flow_invitation, cbv_applicant: flow.cbv_applicant) }

      before { flow.destroy! }

      it "preserves the applicant while the invitation is valid" do
        service.redact_incomplete_cbv_flows

        expect_redacted(income_flow)
        expect(active_invitation.reload.redacted_at).to be_nil
        expect(income_flow.cbv_applicant.reload.redacted_at).to be_nil
      end
    end

    context "with an expired CE invitation but no CE flow" do
      let!(:expired_invitation) { create(:activity_flow_invitation, cbv_applicant: flow.cbv_applicant, expires_at: 1.day.ago) }

      before { flow.destroy! }

      it "redacts the applicant without waiting for invitation retention" do
        service.redact_incomplete_cbv_flows

        expect_redacted(income_flow)
        expect_redacted(income_flow.cbv_applicant)
        expect(expired_invitation.reload.redacted_at).to be_nil
      end
    end
  end
end
