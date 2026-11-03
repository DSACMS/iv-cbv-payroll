# Context for NSC-backed education events, including its partially self-attested steps.
# Fully self-attested education keeps its existing instrumentation unchanged.
module NscEducationTracking
  extend ActiveSupport::Concern

  included do
    helper_method :nsc_education_tracking_attributes
  end

  private

  def standard_track_attributes
    super.merge(nsc_education_tracking_attributes)
  end

  def nsc_education_tracking_attributes
    activity = @education_activity || @activity
    return {} unless activity.is_a?(EducationActivity) && activity.persisted? && !activity.fully_self_attested?

    {
      education_flow: "nsc",
      education_activity_id: activity.id,
      education_data_source: activity.sync_unknown? ? "pending" : activity.data_source,
      nsc_status: activity.status,
      education_type: activity.education_type,
      from_edit: params[:from_edit].presence,
      from_review: params[:from_review].presence
    }
  end
end
