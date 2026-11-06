class Activities::Education::TermCreditHoursController < Activities::BaseController
  include NavigationTracking

  before_action :redirect_if_nsc_disabled
  before_action :set_education_activity
  before_action :set_term_credit_hours_vars, only: %i[edit update]
  before_action :set_back_url, only: %i[edit update]
  after_action :track_term_credit_hours_viewed_event, only: :edit
  after_action :track_term_credit_hours_submission_event, only: :update

  def edit
  end

  def update
    assign_term_credit_hours_submission_values

    if !valid_term_credit_hours_submission?
      @error = true
      render :edit, status: :unprocessable_content
      return
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
        education_id: @education_activity, id: next_index, from_edit: params[:from_edit].presence
      )
    else
      redirect_to new_activities_flow_education_document_upload_path(
        education_id: @education_activity, from_edit: params[:from_edit].presence
      )
    end
  end

  private

  def track_term_credit_hours_viewed_event
    return unless response.successful?

    track_event(
      TrackEvent::EducationTermCreditHoursViewed,
      education_activity_id: @education_activity.id,
      term_index: @term_index,
      term_date_range: @current_term.term_date_display
    )
  end

  def track_term_credit_hours_submission_event
    return unless @current_term.present?

    event = @error ? TrackEvent::EducationTermCreditHoursValidationFailed : TrackEvent::EducationTermCreditHoursSubmitted
    attributes = {
      education_activity_id: @education_activity.id,
      term_index: @term_index,
      term_date_range: @current_term.term_date_display
    }
    attributes[:error_fields] = @current_term.errors.attribute_names.map(&:to_s) if @error
    track_event(event, attributes)
  end

  def assign_term_credit_hours_submission_values
    @current_term.assign_attributes(term_credit_hours_params)
    @current_term.no_hours = params[:no_hours] == "1"
    @current_term.credit_hours = 0 if @current_term.credit_hours_before_type_cast.blank?
  end

  def valid_term_credit_hours_submission?
    return false unless @current_term.valid?(:supplemental_details)
    return true if params[:from_review].blank? && @term_index < @terms.length - 1

    if @terms.any?(&:supplemental_sufficient_enrollment?) || @terms.sum { |term| term.credit_hours || 0 } > 0
      return true
    end

    @current_term.errors.add(:credit_hours, I18n.t("activities.education.term_credit_hours.field_error"))
    @no_hours_error = true
    false
  end

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
    @current_term.no_hours = @current_term.credit_hours == 0 && @current_term.supplemental_enrollment_status.blank?
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
                    education_id: @education_activity, id: @term_index - 1, from_edit: params[:from_edit].presence
                  )
                else
                  edit_activities_flow_education_path(id: @education_activity, from_edit: params[:from_edit].presence)
                end
  end

  def term_credit_hours_params
    params.require(:nsc_enrollment_term).permit(:credit_hours, :supplemental_enrollment_status)
  end

  def mixed_enrollment_in_window?
    reporting_range = @flow.reporting_window_range
    @education_activity.nsc_enrollment_terms
      .any? { |term| term.within_reporting_window?(reporting_range) && term.half_time_or_above? }
  end
end
