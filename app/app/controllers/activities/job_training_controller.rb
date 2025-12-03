class Activities::JobTrainingController < Activities::BaseController
  def new
    @job_training_activity = @activity_flow.job_training_activities.new
  end

  def create
    @job_training_activity = @activity_flow.job_training_activities.new(job_training_activity_params)
    if @job_training_activity.save
      redirect_to activities_flow_root_path, notice: t("activities.job_training.created")
    else
      render :new
    end
  end

  private

  def job_training_activity_params
    params.require(:job_training_activity).permit(:program_name, :organization_address, :hours)
  end
end
