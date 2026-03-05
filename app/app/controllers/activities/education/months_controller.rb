class Activities::Education::MonthsController < Activities::BaseController
  before_action :set_education_activity
  before_action :redirect_validated_activity, only: %i[edit update]

  include MonthlyHoursInput

  private

  def set_education_activity
    @education_activity = @flow.education_activities.find(params[:education_id])
  end

  def redirect_validated_activity
    redirect_to after_activity_path unless @education_activity.self_attested?
  end

  def hours_input_activity
    @education_activity
  end

  def activity_month_param_key
    :education_activity_month
  end

  def hours_input_path(month_index, from_edit: nil)
    edit_activities_flow_education_month_path(education_id: @education_activity, id: month_index, from_edit: from_edit.presence)
  end

  def activity_display_name
    @education_activity.school_name
  end

  def hours_input_t_scope
    "activities.education.hours_input"
  end

  def hours_input_completed_path
    new_activities_flow_education_document_upload_path(education_id: @education_activity.id, from_edit: params[:from_edit].presence)
  end
end
