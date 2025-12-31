class Activities::JobTrainingController < Activities::BaseController
  before_action :set_job_training_activity, only: %i[edit update destroy]

  def new
    @job_training_activity = @flow.job_training_activities.new
  end

  def create
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params)
    if @job_training_activity.save
      redirect_to activities_flow_root_path, notice: t("activities.job_training.created")
    else
      render :new
    end
  end

  def update
    if @job_training_activity.update(job_training_activity_params)
      redirect_to activities_flow_root_path, notice: t("activities.job_training.updated")
    else
      render :edit
    end
  end

  def destroy
    @job_training_activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.job_training.deleted")
  end

  private

  def set_job_training_activity
    @job_training_activity = @flow.job_training_activities.find(params[:id])
  end

  def job_training_activity_params
    params.require(:job_training_activity).permit(:program_name, :organization_address, :hours, :date)
  end
end
