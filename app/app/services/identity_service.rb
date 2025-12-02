# Abstracts initializing {Identity} at the beginning of a request
class IdentityService
  class DefaultIdentityService
    # Looks up `Identity` by name and DOB.
    #
    # @return [Identity]
    def self.call(request)
      params = request.params
      session = request.session

      attrs   = self.identity_attrs_from_session request.session
      attrs ||= self.identity_attrs_from_params request.params

      if attrs
        Identity.find_by(**attrs) || Identity.build(**attrs)
      else
        Identity.new
      end
    end

    private

    def self.identity_attrs_from_session(session)
      if session.has_key? :identity
        session[:identity]
      end
    end

    def self.identity_attrs_from_params(params)
      if params.has_key? :identity
        params[:identity]
      end
    end
  end

  class LocalIdentityService
    # Invokes {DefaultIdentityService.call} and inserts fake data if
    # the Identity does not currently exist.
    #
    # @return [Identity]
    def self.call(request)
      id = DefaultIdentityService.call(request)
      unless id.first_name
        Rails.logger.info("Faking an identity")
        require "faker"

        id = Identity.build(
          first_name: Faker::Name.first_name,
          last_name:  Faker::Name.last_name,
          date_of_birth: Faker::Date.birthday(min_age: 18, max_age: 65)
        )
      end
      id
    end
  end

  # Initialize an instance of this service using the current `params`
  # object.
  #
  # This finds an appropriate implementation based on the current
  # `Rails.env`.
  #
  # @param request [ActiveDispatch::Request]
  #
  # @raise [NotImplementedError] When the current `Rails.env` does not
  #   have an appropriate implementation
  def initialize(request)
    @request = request
    if Rails.env.local?
      @impl = LocalIdentityService
    elsif Rails.env.production?
      @impl = DefaultIdentityService
    else
      raise NotImplementedError
    end
  end

  # Infer the `Identity` that is associated with the current request
  #
  # @return [Identity] An Identity instance that may or may not
  #   already exist in the database
  def call
    @impl.call(@request)
  end
end
