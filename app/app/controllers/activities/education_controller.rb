class Activities::EducationController < Activities::BaseController
  # Keep the user on the loading page (the #show action) at least this long.
  ARTIFICIAL_DELAY = 2.seconds

  def new
    @education_activity = @flow.education_activities.create

    NscSynchronizationJob.perform_later(@education_activity.id)

    redirect_to activities_flow_education_path(id: @education_activity.id)
  end

  def show
    @education_activity = @flow.education_activities.find(params[:id])
    @polling_url = activities_flow_education_sync_path(education_id: @education_activity.id)

    unless @education_activity.sync_unknown?
      redirect_to edit_activities_flow_education_path(id: params[:id])
    end
  end

  def update
    @education_activity = @flow.education_activities.find(params[:id])
    if @education_activity.update(education_params)
      redirect_to after_activity_path
    else
      redirect_to :edit, flash: { alert: t("activities.education.errors.unexpected") }
    end
  end

  def edit
    @education_activity = @flow.education_activities.find(params[:id])
    @student_information = current_identity!

    unless @education_activity
      redirect_to(
        activities_flow_root_path,
        flash: { alert: t("activities.education.error_no_data") }
      )
    end
  end

  def destroy
    activity = @flow.education_activities.find(params[:id])
    activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.education.deleted")
  end

  def sync
    @education_activity = @flow.education_activities.find(params[:education_id])

    if @education_activity.sync_unknown?
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    elsif @education_activity.sync_failed?
      render turbo_stream: turbo_stream.action(:redirect, activities_flow_error_path)
    elsif @education_activity.created_at > ARTIFICIAL_DELAY.ago
      render turbo_stream: turbo_stream.replace(:synchronization, partial: "status")
    else
      render turbo_stream: turbo_stream.action(:redirect, edit_activities_flow_education_path(id: @education_activity))
    end
  end

  def error
  end

  private

  def education_params
    params
      .require(:education_activity)
      .permit(
        :id,
        :additional_comments,
        :credit_hours
      )
  end
end
