class VolunteeringActivity < Activity
  include HasActivityMonths
  include DocumentUploadable

  has_many :volunteering_activity_months, dependent: :destroy
  has_activity_months :volunteering_activity_months

  def document_upload_object_title
    organization_name
  end
end
