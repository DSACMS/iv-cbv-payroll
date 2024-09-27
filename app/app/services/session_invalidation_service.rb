# This class implements session expiration based on the session ID. After
# logout, the session ID is stored in a database JSON column (along with the
# current timestamp). This column is consulted on every request and
# authentication is denied if the current session ID is in the invalidated
# list.
#
# This class is not auto-reloaded in development.
class SessionInvalidationService
  def self.register_hooks!
    # On every authenticated page, ensure the session hasn't been invalidated:
    Warden::Manager.after_fetch do |user, auth, opts|
      unless new(user, auth.request.session.id.to_s).valid?
        scope = opts[:scope]
        auth.logout(scope)
        throw(:warden, scope: scope, reason: "Session Invalidated")
      end
    end

    # After logging in, remove any prior invalidations for the current session:
    Warden::Manager.after_authentication do |user, auth, opts|
      new(user, auth.request.session.id.to_s).remove_invalidation!
    end

    # When logging out, invalidate the session:
    Warden::Manager.before_logout do |user, auth, opts|
      new(user, auth.request.session.id.to_s).invalidate!
    end
  end

  def initialize(user, session_id)
    @user = user
    @session_id = session_id
  end

  def valid?
    return false unless @user.present?

    (@user.invalidated_session_ids || {}).exclude?(@session_id)
  end

  def invalidate!
    return unless valid?

    @user.invalidated_session_ids ||= {}
    @user.invalidated_session_ids[@session_id] = Time.now.to_i
    remove_stale_invalid_sessions(@user.invalidated_session_ids)
    @user.save
  end

  def remove_invalidation!
    return if valid?

    @user.invalidated_session_ids ||= {}
    @user.invalidated_session_ids = @user.invalidated_session_ids.except(@session_id)
    @user.save
  end

  private

  def remove_stale_invalid_sessions(invalidated_session_ids, delay: Devise.timeout_in)
    invalidated_session_ids.delete_if do |id, timestamp|
      Time.at(timestamp).before?(delay.ago)
    end
  end
end
