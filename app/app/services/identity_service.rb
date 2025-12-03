# Abstracts initializing {Identity} at the beginning of a request
class IdentityService
  class DefaultIdentityService
    # Looks up `Identity` by name and DOB.
    #
    # @param [ActionDispatch::Request] request The request to read from
    #
    # @return [Identity, nil]
    def self.read_identity(request)
      params = request.params
      session = request.session

      attrs   = self.identity_attrs_from_session request.session
      attrs ||= self.identity_attrs_from_params request.params

      if attrs
        Identity.find_or_create_by(attrs.slice([:first_name, :last_name, :date_of_birth]))
      else
        nil
      end
    end

    # Save an {Identity} into the current session
    #
    # @param [ActionDispatch::Request] request The current request
    # @param [Identity] identity The current identity
    #
    # @return [Identity] the identity param
    def self.save_identity(request, identity)
      request.session[:identity] = identity.attributes
      identity
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
    # Invokes {DefaultIdentityService.read_identity} and inserts fake
    # data if the Identity does not currently exist.
    #
    # @return [Identity]
    def self.read_identity(request)
      id = DefaultIdentityService.read_identity(request)
      unless id
        require "faker"

        id = Identity.find_or_create_by(
          first_name: Faker::Name.first_name,
          last_name:  Faker::Name.last_name,
          date_of_birth: Faker::Date.birthday(min_age: 18, max_age: 65)
        )
      end
      id
    end

    # Invokes {DefaultIdentityService.save_identity}
    #
    # @param [ActionDispatch::Request] request The current request
    # @param [Identity] identity The current identity
    #
    # @return [Identity] the identity param
    def self.save_identity(request, identity)
      DefaultIdentityService.save_identity(request, identity)
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
    if Rails.env.development?
      @impl = LocalIdentityService
    else
      @impl = DefaultIdentityService
    end
  end

  # Infer the `Identity` that is associated with the current request
  #
  # @return [Identity, nil] An Identity instance that may or may not
  #   already exist in the database. nil if no identity is associated
  #   with this request
  def read_identity
    @impl.read_identity(@request)
  end

  # Save an {Identity} in a way that can be read back by
  # {#read_identity}
  #
  # @param [Identity] identity The current identity
  #
  # @return [Identity] the identity param
  def save_identity(identity)
    @impl.save_identity(@request, identity)
  end
end
