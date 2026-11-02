class Activities::SubmitController < Activities::BaseController
  skip_before_action :ensure_activity_flow_not_yet_complete, only: :show

  def show
    respond_to do |format|
      format.html
      format.pdf { render_pdf }
    end
  end

  private

  def render_pdf
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "#{1.year.ago}"

    @report = ActivityPdfReport.new(
      flow: @flow,
      caseworker: internal_environment? && params[:is_caseworker] == "true"
    )

    html = render_to_string(template: "activities/submit/show", formats: [ :pdf ], layout: "pdf")
    send_data PdfRenderer.render(html, margin: pdf_margins),
      filename: "#{pdf_filename}.pdf", type: "application/pdf", disposition: "inline"
  end

  def pdf_filename
    "HR1_Report_#{Time.zone.today.strftime("%Y-%m-%d")}"
  end

  def pdf_margins
    {
      top: 8,
      bottom: 8,
      left: 0,
      right: 0
    }
  end
end
