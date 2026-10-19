require "rails_helper"

# This integration spec stays in the requested 508-specific test directory.
# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Activities::SubmitController, type: :controller do
  include_context "activity_hub"
  render_views

  let(:identity) { create(:identity, activity_flows_count: 0) }
  let(:cbv_applicant) { create(:cbv_applicant, first_name: "Synthetic", last_name: "Report") }
  let(:activity_flow) do
    create(
      :activity_flow,
      cbv_applicant: cbv_applicant,
      identity: identity,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      reporting_window_months: 2
    )
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  it "generates a tagged PDF with table captions and document metadata" do
    rendered_html = nil
    allow(TaggedPdfRenderer).to receive(:render).and_wrap_original do |renderer, html, **options|
      rendered_html = html
      renderer.call(html, **options)
    end

    get :show, format: :pdf

    expect(response).to have_http_status(:ok)
    expect(rendered_html).to be_present
    rendered_tables = Nokogiri::HTML(rendered_html).css("table")
    expect(rendered_tables).to be_present
    expect(rendered_tables.css("caption")).to be_present
    expect(response.body).to start_with("%PDF-")
    expect(response.body).to include("/StructTreeRoot", "/MarkInfo", "/Lang", "/Title")
    tag_roles = response.body.scan(%r{/S\s*/([A-Za-z]+)}).flatten.uniq
    expect(tag_roles).to include("Caption")
    expect(PDF::Reader.new(StringIO.new(response.body)).page_count).to be > 0
  end

  it "keeps the community-engagement-hours column heading on one line" do
    employment = create(:employment_activity, activity_flow: activity_flow, employer_name: "Synthetic Employer")
    create(
      :employment_activity_month,
      employment_activity: employment,
      month: activity_flow.reporting_months.first,
      hours: 12,
      gross_income: 240
    )
    rendered_html = nil
    allow(TaggedPdfRenderer).to receive(:render).and_wrap_original do |renderer, html, **options|
      rendered_html = html
      renderer.call(html, **options)
    end

    get :show, format: :pdf

    document = Nokogiri::HTML(rendered_html)
    expected_header = I18n.t("activities.summary.employment.community_engagement_hours")
    hours_header = document.css("th").find do |header|
      header.text.gsub(/\s+/, " ").strip == expected_header
    end
    expect(hours_header).to be_present
    expect(hours_header.css("span.activity-report__no-wrap-header")).to be_present

    pdf_text = PDF::Reader.new(StringIO.new(response.body)).pages.map(&:text).join("\n")
    expect(pdf_text).to include(I18n.t("activities.summary.employment.community_engagement_hours"))
  end

  it "keeps long activity comments from creating cross-page marked-content references" do
    create(
      :volunteering_activity,
      activity_flow: activity_flow,
      organization_name: "Synthetic Organization",
      additional_comments: "A long comment. " * 60
    )

    get :show, format: :pdf

    expect(response.body).to start_with("%PDF-")
    expect(response.body.scan(%r{/Type /MCR}).length).to eq(0)
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
