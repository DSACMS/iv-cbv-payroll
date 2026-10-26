module InvitationExpiration
  extend ActiveSupport::Concern

  INVITATION_VALIDITY_TIME_ZONE = "America/New_York"

  included do
    before_create :set_expires_at, if: :new_record?
  end

  private

  def set_expires_at
    self.expires_at ||= calculate_expires_at
  end

  # Invitations are valid until 11:59pm Eastern Time on the (e.g.) 14th day
  # after sending the invitation.
  def calculate_expires_at
    end_of_day_sent = created_at.in_time_zone(INVITATION_VALIDITY_TIME_ZONE).end_of_day
    days_valid_for = Rails.application.config.client_agencies[client_agency_id].invitation_valid_days

    end_of_day_sent + days_valid_for.days
  end
end
