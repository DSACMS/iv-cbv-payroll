class Activities::SubmitController < Activities::BaseController
  def show
  end

  def update
    unless params.dig(:activity_flow, :consent_to_submit) == "1"
      flash.now[:alert] = t("activities.submit.consent_required")
      return render :show, status: :unprocessable_content
    end

    @activity_flow.touch(:completed_at)
    redirect_to next_path
  end
end
