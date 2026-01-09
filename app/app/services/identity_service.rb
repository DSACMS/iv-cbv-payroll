require "faker"
# Abstracts initializing {Identity} at the beginning of a request flow
class IdentityService
  # Initialize an instance of this service using the current `params`
  # object and optional applicant data.
  #
  # @param request [ActionDispatch::Request] The current request object
  # @param cbv_applicant [CbvApplicant, nil] An optional CBV
  def initialize(request, cbv_applicant = nil)
    @request = request
    @cbv_applicant = cbv_applicant
  end

  # Infer the `Identity` that is associated with the current request
  # @return [Identity] and Identity instance
  def get_identity
    if @cbv_applicant&.first_name.present?
      # Use the identity associated with the CBV applicant if available
      Identity.find_or_create_by(
        first_name: @cbv_applicant.first_name,
        last_name:  @cbv_applicant.last_name,
        date_of_birth: @cbv_applicant.date_of_birth
      )
    else
      # Fallback: Create a dummy identity for demonstration purposes
      Rails.logger.info("[IdentityService] No CBV applicant data found, generating dummy identity")
      Identity.create(
        first_name: Faker::Name.first_name,
        last_name:  Faker::Name.last_name,
        date_of_birth: Faker::Date.birthday(min_age: 18, max_age: 65)
      )
    end
  end
end
