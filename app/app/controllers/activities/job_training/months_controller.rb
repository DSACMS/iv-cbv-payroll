class Activities::JobTraining::MonthsController < Activities::BaseController
  before_action :set_job_training_activity

  include MonthlyHoursInput
  include NavigationTracking

  before_action :set_back_url, only: %i[edit update]

  after_action :track_month_viewed_event, only: :edit
  after_action :track_month_submission_event, only: :update

  private

  def month_event_attributes
    {
      job_training_activity_id: @job_training_activity.id,
      month_index: @month_index,
      month: I18n.l(@current_month, format: :month_year)
    }
  end

  def track_month_viewed_event
    return unless response.successful?

    track_event(TrackEvent::WorkProgramMonthViewed, month_event_attributes)
  end

  def track_month_submission_event
    return unless @activity_month.present?

    if @error
      track_event(TrackEvent::WorkProgramMonthValidationFailed, month_event_attributes.merge(error_fields: %w[hours]))
    else
      track_event(TrackEvent::WorkProgramMonthSubmitted, month_event_attributes)
    end
  end

  def set_back_url
    @back_url = if params[:from_review].present?
                  review_activities_flow_job_training_path(
                    id: @job_training_activity,
                    from_edit: params[:from_edit].presence
                  )
                elsif @month_index > 0
                  hours_input_path(@month_index - 1, from_edit: params[:from_edit].presence)
                else
                  edit_activities_flow_job_training_path(id: @job_training_activity)
                end
  end

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
    if params[:from_review].present?
      review_activities_flow_job_training_path(id: @job_training_activity, from_edit: params[:from_edit].presence)
    else
      new_activities_flow_job_training_document_upload_path(job_training_id: @job_training_activity.id, from_edit: params[:from_edit].presence)
    end
  end
end
