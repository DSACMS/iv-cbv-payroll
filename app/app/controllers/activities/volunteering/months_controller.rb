class Activities::Volunteering::MonthsController < Activities::BaseController
  before_action :set_volunteering_activity

  include MonthlyHoursInput

  private

  def set_volunteering_activity
    @volunteering_activity = @flow.volunteering_activities.find(params[:volunteering_id])
  end

  def hours_input_activity
    @volunteering_activity
  end

  def activity_month_param_key
    :volunteering_activity_month
  end

  def hours_input_path(month_index, from_edit: nil)
    edit_activities_flow_volunteering_month_path(volunteering_id: @volunteering_activity, id: month_index, from_edit: from_edit.presence)
  end

  def activity_display_name
    @volunteering_activity.organization_name
  end

  def hours_input_t_scope
    "activities.community_service.hours_input"
  end

  def hours_input_completed_notice
    t("activities.community_service.created")
  end

  def hours_input_completed_path
    if params[:from_review].present?
      review_activities_flow_volunteering_path(id: @volunteering_activity, from_edit: params[:from_edit].presence)
    else
      new_activities_flow_volunteering_document_upload_path(volunteering_id: @volunteering_activity.id, from_edit: params[:from_edit].presence)
    end
  end
end
