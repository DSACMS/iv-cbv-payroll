class Activities::Education::TermCreditHoursController < Activities::BaseController
  before_action :set_education_activity
  before_action :set_term_credit_hours_vars, only: %i[edit update]
  before_action :set_back_url, only: %i[edit]

  def edit
  end

  def update
    if params[:no_hours] == "1"
      @current_term.credit_hours = 0
    else
      @current_term.credit_hours = term_credit_hours_params[:credit_hours].to_i
    end

    @current_term.save!

    if params[:from_review].present?
      redirect_to review_activities_flow_education_path(
        id: @education_activity,
        from_edit: params[:from_edit].presence
      )
      return
    end

    next_index = @term_index + 1
    if next_index < @terms.length
      redirect_to edit_activities_flow_education_term_credit_hour_path(
        education_id: @education_activity, id: next_index
      )
    else
      redirect_to new_activities_flow_education_document_upload_path(
        education_id: @education_activity
      )
    end
  end

  private

  def set_education_activity
    @education_activity = @flow.education_activities.find(params[:education_id])
  end

  def set_term_credit_hours_vars
    @terms = @education_activity.less_than_half_time_terms_in_reporting_window

    if @terms.empty?
      redirect_to after_activity_path
      return
    end

    @term_index = (params[:id] || 0).to_i

    if @term_index < 0 || @term_index >= @terms.length
      redirect_to edit_activities_flow_education_term_credit_hour_path(
        education_id: @education_activity, id: 0
      )
      return
    end

    @current_term = @terms[@term_index]
    @show_no_hours_checkbox = @terms.many? || mixed_enrollment_in_window?
  end

  def set_back_url
    @back_url = if params[:from_review].present?
                  review_activities_flow_education_path(
                    id: @education_activity,
                    from_edit: params[:from_edit].presence
                  )
                elsif @term_index > 0
                  edit_activities_flow_education_term_credit_hour_path(
                    education_id: @education_activity, id: @term_index - 1
                  )
                else
                  edit_activities_flow_education_path(id: @education_activity)
                end
  end

  def term_credit_hours_params
    params.require(:nsc_enrollment_term).permit(:credit_hours)
  end

  def mixed_enrollment_in_window?
    reporting_range = @flow.reporting_window_range
    @education_activity.nsc_enrollment_terms
      .any? { |term| term.within_reporting_window?(reporting_range) && term.half_time_or_above? }
  end
end
