class Activities::SubmitController < Activities::BaseController
  def show
    respond_to do |format|
      format.html
      format.pdf { render_pdf }
    end
  end

  def update
    unless params.dig(:activity_flow, :consent_to_submit) == "1"
      flash.now[:alert] = t("activities.submit.consent_required")
      return render :show, status: :unprocessable_content
    end

    @flow.touch(:completed_at)
    redirect_to next_path
  end

  private

  def render_pdf
    @volunteering_activities = @activity_flow.volunteering_activities.order(date: :desc, created_at: :desc)
    @job_training_activities = @activity_flow.job_training_activities.order(created_at: :desc)
    @submission_timestamp = submission_timestamp
    progress = ActivityFlowProgressCalculator.progress(@activity_flow)
    @total_hours = progress.total_hours

    render pdf: pdf_filename,
      layout: "pdf",
      template: "activities/submit/show",
      margin: pdf_margins,
      disposition: "inline"
  end

  def submission_timestamp
    @activity_flow.completed_at || Time.zone.now
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
