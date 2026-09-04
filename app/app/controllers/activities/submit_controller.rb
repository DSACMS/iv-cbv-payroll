class Activities::SubmitController < Activities::BaseController
  def show
    respond_to do |format|
      format.html
      format.pdf { render_pdf }
    end
  end

  private

  def render_pdf
    @report = ActivityPdfReport.new(
      flow: @flow,
      caseworker: internal_environment? && params[:is_caseworker] == "true"
    )

    render pdf: pdf_filename,
      layout: "pdf",
      template: "activities/submit/show",
      margin: pdf_margins,
      disposition: "inline"
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
