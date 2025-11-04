class Cbv::PreviewController < ApplicationController
  include NonProductionAccessible
  include Cbv::AggregatorDataHelper

  layout "preview"

  before_action :ensure_non_production_environment
  before_action :setup_preview_flow
  before_action :set_aggregator_report, only: %i[payment_details summary submit submit_pdf_as_html]
  before_action :relax_csp_for_html_preview, only: %i[submit_pdf_as_html]

  helper_method :current_agency, :employer_name, :gross_pay, :employment_start_date,
    :employment_end_date, :employment_status, :pay_frequency, :compensation_unit,
    :compensation_amount, :account_comment, :has_income_data?, :has_consent,
    :agency_url, :next_path, :get_comment_by_account_id

  def employer_search
    @query = params[:query] || ""
    @employers = []
    @has_payroll_account = @cbv_flow.payroll_accounts.any?
    @selected_tab = params[:type] || "payroll"

    render_as("employer_searches")
  end

  def synchronizations
    @payroll_account = @cbv_flow.payroll_accounts.first
    # Set params that the view expects
    params[:user] = { account_id: @payroll_account.pinwheel_account_id }

    render_as("synchronizations")
  end

  def payment_details
    @payroll_account = @cbv_flow.payroll_accounts.first
    # Set params that the view expects
    params[:user] = { account_id: @payroll_account.pinwheel_account_id }

    @payroll_account_report = @aggregator_report.find_account_report(@payroll_account.pinwheel_account_id)
    @is_w2_worker = @payroll_account_report.employment.employment_type == :w2
    @account_comment = account_comment

    render_as("payment_details")
  end

  def summary
    render_as("summaries")
  end

  def submit
    respond_to do |format|
      format.html do
        render_as("submits")
      end
      format.pdf do
        render pdf: "#{@cbv_flow.id}",
          template: "cbv/submits/show",
          formats: [ :pdf ],
          layout: "pdf",
          locals: {
            is_caseworker: is_not_production? && params[:is_caseworker],
            aggregator_report: @aggregator_report
          },
          footer: { right: t("cbv.submits.show.pdf.footer.page_footer"), font_size: 10 },
          margin: {
            top: 10,
            bottom: 10,
            left: 10,
            right: 10
          }
      end
    end
  end

  def submit_pdf_as_html
    # Render the PDF template as HTML for debugging (no wkhtmltopdf conversion)
    is_caseworker = is_not_production? && params[:is_caseworker]

    # Render the PDF template and layout manually
    html_content = render_to_string(
      template: "cbv/submits/show",
      formats: [ :pdf ],
      layout: "pdf",
      locals: {
        is_caseworker: is_caseworker,
        aggregator_report: @aggregator_report
      }
    )

    # Wrap in preview layout for consistency
    render html: html_content.html_safe, layout: "preview"
  end

  private

  def show_translate_button?
    true
  end

  def relax_csp_for_html_preview
    # Allow inline styles for the HTML preview (development CSS is inlined)
    request.content_security_policy.style_src :self, :unsafe_inline
  end

  def render_as(controller_name)
    # Modify lookup context prefixes to include the target controller's views
    @_lookup_context&.prefixes&.unshift("cbv/#{controller_name}")
    render template: "cbv/#{controller_name}/show"
  end

  def ensure_non_production_environment
    unless is_not_production?
      render plain: "Preview routes are only available in non-production environments", status: :forbidden
    end
  end

  def setup_preview_flow
    client_agency_id = params[:client_agency_id] || "sandbox"

    # Validate client_agency_id
    unless Rails.application.config.client_agencies.client_agency_ids.include?(client_agency_id)
      return render plain: "Invalid client_agency_id", status: :unprocessable_entity
    end

    # Create or reuse test data
    @cbv_flow = create_synced_flow(client_agency_id)
    @cbv_applicant = @cbv_flow.cbv_applicant
  end

  def argyle_account_id
    # Dynamically get account ID from the selected fixture user's data
    fixture_user = params[:fixture_user] || "bob"
    fixture_path = Rails.root.join("spec", "support", "fixtures", "argyle", fixture_user, "request_account.json")

    if File.exist?(fixture_path)
      account_data = JSON.parse(File.read(fixture_path))
      account_data["id"]
    else
      # Fallback to Bob's ID if fixture doesn't exist
      "019571bc-2f60-3955-d972-dbadfe0913a8"
    end
  end

  def create_synced_flow(client_agency_id)
    cbv_applicant = CbvApplicant.create!(
      client_agency_id: client_agency_id,
      first_name: "Preview",
      last_name: "User",
      case_number: "PREVIEW123",
      snap_application_date: Date.current
    )

    cbv_flow = CbvFlow.create!(
      client_agency_id: client_agency_id,
      cbv_applicant: cbv_applicant,
      consented_to_authorized_use_at: Time.current
    )

    # Create fully synced payroll account
    payroll_account = PayrollAccount::Argyle.create!(
      cbv_flow: cbv_flow,
      aggregator_account_id: argyle_account_id,
      pinwheel_account_id: argyle_account_id,
      supported_jobs: %w[accounts income paystubs employment identity],
      synchronization_status: :succeeded
    )

    # Create successful webhook events
    [
      { event_name: "accounts.connected", event_outcome: "success" },
      { event_name: "identities.added", event_outcome: "success" },
      { event_name: "paystubs.fully_synced", event_outcome: "success" }
    ].each do |event|
      WebhookEvent.create!(
        payroll_account: payroll_account,
        event_name: event[:event_name],
        event_outcome: event[:event_outcome]
      )
    end

    cbv_flow
  end

  def current_agency
    return unless @cbv_flow.present? && @cbv_flow.client_agency_id.present?
    @current_agency ||= Rails.application.config.client_agencies[@cbv_flow.client_agency_id]
  end

  def argyle
    # Force mock environment for preview with selected fixture user
    fixture_user = params[:fixture_user] || "bob"
    Aggregators::Sdk::ArgyleService.new(:mock, fixture_user: fixture_user)
  end

  def pinwheel
    # Force mock environment for preview (if needed)
    Aggregators::Sdk::PinwheelService.new(:mock) rescue nil
  end

  # Helper methods for payment_details
  def has_income_data?
    @payroll_account&.job_succeeded?("income")
  end

  def has_employment_data?
    @payroll_account&.job_succeeded?("employment")
  end

  def has_paystubs_data?
    @payroll_account&.job_succeeded?("paystubs")
  end

  def employer_name
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?
    @payroll_account_report.employment.employer_name
  end

  def employment_start_date
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?
    @payroll_account_report.employment.start_date
  end

  def employment_end_date
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?
    @payroll_account_report.employment.termination_date
  end

  def employment_status
    return I18n.t("cbv.payment_details.show.unknown") unless has_employment_data?
    @payroll_account_report.employment.status&.humanize
  end

  def pay_frequency
    return I18n.t("cbv.payment_details.show.unknown") unless has_income_data?
    @payroll_account_report.income.pay_frequency&.humanize
  end

  def compensation_unit
    return I18n.t("cbv.payment_details.show.unknown") unless has_income_data?
    @payroll_account_report.income.compensation_unit
  end

  def compensation_amount
    return I18n.t("cbv.payment_details.show.unknown") unless has_income_data?
    @payroll_account_report.income.compensation_amount
  end

  def gross_pay
    return I18n.t("cbv.payment_details.show.unknown") unless has_paystubs_data?
    @payroll_account_report.paystubs
      .map { |paystub| paystub.gross_pay_amount.to_i }
      .reduce(:+)
  end

  def account_comment
    ""
  end

  # Helper methods for submits
  def has_consent
    @cbv_flow.consented_to_authorized_use_at.present?
  end

  def agency_url
    current_agency&.agency_contact_website
  end

  def next_path
    ""
  end

  def get_comment_by_account_id(account_id)
    { "comment" => nil, "updated_at" => nil }
  end
end
