class EducationTrackingAttributes
  def initialize(education_activity)
    @education_activity = education_activity
  end

  def to_h
    flow = @education_activity.activity_flow

    {
      flow_type: "ce",
      cbv_flow_id: flow.id,
      cbv_applicant_id: flow.cbv_applicant_id,
      invitation_id: flow.invitation_id,
      client_agency_id: flow.cbv_applicant.client_agency_id,
      device_id: flow.device_id,
      education_activity_id: @education_activity.id,
      education_flow: "nsc",
      education_data_source: @education_activity.sync_unknown? ? "pending" : @education_activity.data_source,
      nsc_status: @education_activity.status,
      education_type: @education_activity.education_type
    }
  end
end
