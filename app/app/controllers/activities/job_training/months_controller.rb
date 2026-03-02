class Activities::JobTraining::MonthsController < Activities::BaseController
  before_action :set_job_training_activity

  include MonthlyHoursInput

  private

  def set_job_training_activity
    @job_training_activity = @flow.job_training_activities.find(params[:job_training_id])
  end

  def hours_input_activity
    @job_training_activity
  end

  def activity_month_param_key
    :job_training_activity_month
  end

  def hours_input_path(month_index, from_edit: nil)
    edit_activities_flow_job_training_month_path(job_training_id: @job_training_activity, id: month_index, from_edit: from_edit.presence)
  end

  def activity_display_name
    @job_training_activity.program_name
  end

  def hours_input_t_scope
    "activities.work_programs.hours_input"
  end

  def hours_input_completed_path
    new_activities_flow_job_training_document_upload_path(job_training_id: @job_training_activity.id, from_edit: params[:from_edit].presence)
  end
end
