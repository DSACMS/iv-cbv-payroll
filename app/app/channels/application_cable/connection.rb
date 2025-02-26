module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_id

    def connect
      self.session_id = session.id
      self.current_user = find_verified_user

    def session
      @request.session
    end
  end
end
