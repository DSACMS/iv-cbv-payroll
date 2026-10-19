class Activities::SubmitController < Activities::BaseController
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

    html = render_to_string(
      template: "activities/submit/show",
      formats: [ :pdf ],
      layout: "layouts/pdf"
    )
    pdf = TaggedPdfRenderer.render(html, margin: pdf_margins)

    send_data pdf,
      filename: pdf_filename,
      type: "application/pdf",
      disposition: "attachment"
  end

  def pdf_filename
    "HR1_report_#{Time.zone.today.iso8601}.pdf"
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
