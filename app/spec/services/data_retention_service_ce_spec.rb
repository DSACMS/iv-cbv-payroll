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
      let(:invitation) { create(:activity_flow_invitation, created_at: 1.year.ago, updated_at: 1.year.ago) }
      let!(:member) { create(:household_member, activity_flow_invitation: invitation) }

      it "retains invitation-linked flows until an invitation expiration policy exists" do
        service.redact_all!

        expect(flow.reload.redacted_at).to be_nil
        expect(invitation.reload.redacted_at).to be_nil
        expect(member.reload.redacted_at).to be_nil
        expect(member.household.reload.redacted_at).to be_nil
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

      it "keeps the invitation available under the current non-expiring policy" do
        service.redact_complete_activity_flows

        expect_redacted(flow)
        expect(invitation.reload.redacted_at).to be_nil
        expect(flow_applicant.reload.redacted_at).to be_nil
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

  describe "unused CE invitations" do
    let!(:unused_invitation) { create(:activity_flow_invitation, created_at: 1.year.ago, updated_at: 1.year.ago) }

    it "retains unused invitations until an expiration policy exists" do
      expect { service.redact_all! }.not_to change { unused_invitation.reload.attributes }
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
  end
end
