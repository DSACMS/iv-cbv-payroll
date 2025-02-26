module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :session_id

    def connect
      self.current_user = find_verified_user
      self.session_id = session.id
      logger.add_tags "ActionCable", current_user&.id || "Guest-#{session_id}"
    end

    def session
      @request.session
    end

    private

    def find_verified_user
      if verified_user = env['warden'].user
        verified_user
      else
        nil
      end
    end
  end
end
