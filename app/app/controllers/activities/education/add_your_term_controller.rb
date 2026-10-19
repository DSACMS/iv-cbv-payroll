class Activities::Education::AddYourTermController < Activities::BaseController
  include NavigationTracking

  before_action :set_education_activity
  before_action :set_back_url
  after_action :track_add_term_viewed_event, only: :edit
  after_action :track_add_term_submission_event, only: :update

  def edit
  end

  def update
    assign_term_submission_values

    if @education_activity.save(context: :add_your_term)
      if params[:from_review].present?
        redirect_to review_activities_flow_education_path(id: @education_activity, from_edit: params[:from_edit].presence)
      else
        redirect_to new_activities_flow_education_document_upload_path(
          education_id: @education_activity,
          from_edit: params[:from_edit].presence
        )
      end
    else
      add_invalid_term_date_errors
      @error = true
      error_type = (@invalid_dates.any? || @education_activity.errors.of_kind?(:self_attested_term_end, :invalid)) ? "dates" : "information"
      flash.now[:alert_heading] = t("activities.education.add_your_term.errors.#{error_type}_heading")
      flash.now[:alert] = t("activities.education.add_your_term.errors.#{error_type}_body")
      flash.now[:alert_form_id] = "education-term-form"
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_education_activity
    @education_activity = @flow.education_activities.find(params[:education_id])
    redirect_to after_activity_path unless @education_activity.fully_self_attested?
  end

  def set_back_url
    @back_url = if params[:from_review].present?
                  review_activities_flow_education_path(id: @education_activity, from_edit: params[:from_edit].presence)
                else
                  edit_activities_flow_education_path(id: @education_activity, from_edit: params[:from_edit].presence)
                end
  end

  def term_params
    params.require(:education_activity).permit(
      :self_attested_term_start, :self_attested_term_end, :self_attested_enrollment_status, :credit_hours
    )
  end

  def assign_term_submission_values
    @invalid_dates = []
    attributes = term_params.to_h
    %w[self_attested_term_start self_attested_term_end].each do |attribute|
      value = attributes[attribute]
      attributes[attribute] = DateFormatter.parse_month_year(value)
      @invalid_dates << attribute.to_sym if value.present? && attributes[attribute].nil?
    end
    @education_activity.assign_attributes(attributes)
  end

  def add_invalid_term_date_errors
    @invalid_dates.each do |attribute|
      @education_activity.errors.delete(attribute)
      @education_activity.errors.add(attribute, :invalid)
    end
  end

  def track_add_term_viewed_event
    return unless response.successful?

    track_event(TrackEvent::EducationAddTermViewed, term_event_attributes)
  end

  def track_add_term_submission_event
    attributes = term_event_attributes
    attributes[:error_fields] = @education_activity.errors.attribute_names.map(&:to_s) if @error
    event = @error ? TrackEvent::EducationAddTermValidationFailed : TrackEvent::EducationAddTermSubmitted
    track_event(event, attributes)
  end

  def term_event_attributes
    {
      education_activity_id: @education_activity.id,
      term_date_range: @education_activity.self_attested_term_date_display,
      enrollment_status: @education_activity.self_attested_enrollment_status
    }
  end
end
