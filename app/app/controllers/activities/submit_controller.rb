class Activities::SubmitController < Activities::BaseController
  def show
    respond_to do |format|
      format.html
      format.pdf { render_pdf }
    end
  end

  private

  def render_pdf
    @community_service_activities = @flow.volunteering_activities.order(date: :desc, created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.order(created_at: :desc)
    @education_activities = @flow.education_activities.order(created_at: :desc)
    @submission_timestamp = submission_timestamp
    @total_hours = progress_calculator.overall_result.total_hours

    render pdf: pdf_filename,
      layout: "pdf",
      template: "activities/submit/show",
      margin: pdf_margins,
      disposition: "inline"
  end

  def submission_timestamp
    @flow.completed_at || Time.zone.now
  end

  def pdf_filename
    "HR1_Report_#{Time.zone.today.strftime("%Y-%m-%d")}"
  end

  def pdf_margins
    {
      top: 10,
      bottom: 10,
      left: 10,
      right: 10
    }
  end
end
