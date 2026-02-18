class Activities::JobTrainingController < Activities::BaseController
  before_action :set_job_training_activity, only: %i[edit update destroy]

  def new
    @job_training_activity = @flow.job_training_activities.new
  end

  def create
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params)
    if @job_training_activity.save
      redirect_to after_activity_path(@job_training_activity), notice: t("activities.work_programs.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @job_training_activity.update(job_training_activity_params)
      redirect_to after_activity_path(@job_training_activity), notice: t("activities.work_programs.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @job_training_activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.work_programs.deleted")
  end

  private

  def after_activity_path(activity)
    new_activities_flow_job_training_document_upload_path(job_training_id: activity.id)
  end

  def set_job_training_activity
    @job_training_activity = @flow.job_training_activities.find(params[:id])
  end

  def job_training_activity_params
    params.require(:job_training_activity).permit(:program_name, :organization_address, :hours, :date)
  end
end
