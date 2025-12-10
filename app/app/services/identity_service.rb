# Abstracts initializing {Identity} at the beginning of a request
class IdentityService
  # Initialize an instance of this service using the current `params`
  # object.
  def initialize(request)
    @request = request
  end

  # Infer the `Identity` that is associated with the current request
  #
  # @return [Identity, nil] An Identity instance that may or may not
  #   already exist in the database. nil if no identity is associated
  #   with this request
  def get_identity
    # This currently creates a fake identity for local development and
    # demoing. It's separated into a service class so make it easier
    # to stub in tests. Long term this will be replaced with whatever
    # logic we need got get an identity out of a tokenized link or
    # whatever.
    require "faker"

    id = Identity.find_or_create_by(
      first_name: Faker::Name.first_name,
      last_name:  Faker::Name.last_name,
      date_of_birth: Faker::Date.birthday(min_age: 18, max_age: 65)
    )
  end
end
