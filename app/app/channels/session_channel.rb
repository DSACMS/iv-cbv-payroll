class SessionChannel < ApplicationCable::Channel
  # Check session activity every minute in production, more frequently in development
  periodically :check_session_activity, every: Rails.env.development? ? 5.seconds : 60.seconds

  def subscribed
    return unless connection.session[:cbv_flow_id]
    @cbv_flow = CbvFlow.find(connection.session[:cbv_flow_id])
    stream_for @cbv_flow

    # Record connection time
    connection.instance_variable_set(:@session_channel_connected_at, Time.current)

    # Track this initial connection as an activity
    update_last_activity_time

    # Send initial session info
    transmit_session_info
  end

  def received(data)
    Rails.logger.debug "Data received on SessionChannel: #{data}"
    update_last_activity_time
  end

  def extend_session(data)
    update_last_activity_time
    # Clear any warning flags since the session has been extended
    connection.instance_variable_set(:@warning_sent_at, nil)

    transmit({
      event: "session.extended",
      message: "Session extended successfully",
      extended_at: Time.current.iso8601
    })

    transmit_session_info
    Rails.logger.info "Session successfully extended for #{@cbv_flow.id}"
  end

  def transmit_session_info
    timeout_in = get_timeout_setting

    # Calculate time remaining
    last_active = get_last_activity_time
    time_until_timeout = [ timeout_in - (Time.current - last_active), 0 ].max

    transmit({
      event: "session.info",
      timeout_in_ms: timeout_in * 1000,
      time_remaining_ms: time_until_timeout * 1000,
      last_activity: last_active.iso8601,
      cbv_flow_id: @cbv_flow.id
    })
  end

  private

  def current_channel_identifier
    @cbv_flow.id
  end

  def get_timeout_setting
    # In development, use a shorter timeout for testing (2 minutes)
    Rails.env.development? ? 2.minutes : 30.minutes
  end

  def update_last_activity_time
    current_time = Time.current
    connection.instance_variable_set(:@session_channel_last_activity, current_time)
    # Also update the session timestamp
    if connection.session
      connection.session[:last_activity_at] = current_time.to_i
    end
    Rails.logger.debug "Updated activity time for #{@cbv_flow.id} to #{current_time}"
  end

  def get_last_activity_time
    # Get timestamps from different sources
    websocket_activity = connection.instance_variable_get(:@session_channel_last_activity)
    connection_time = connection.instance_variable_get(:@session_channel_connected_at)
    # Get activity time from the session (if tracked in ApplicationController)
    session_activity = connection.session && connection.session[:last_activity_at].present? ? 
                        Time.at(connection.session[:last_activity_at]) : nil

    # Log the available timestamps for debugging
    timestamps = {
      websocket_activity: websocket_activity,
      session_activity: session_activity, 
      connection_time: connection_time
    }
    Rails.logger.debug "Available timestamps for #{current_channel_identifier}: #{timestamps}"

    # Use the most recent timestamp from any source, fallback to current time
    [ websocket_activity, session_activity, connection_time, Time.current ].compact.max
  end

  def check_session_activity
    Rails.logger.debug "SessionChannel#check_session_activity called at #{Time.current}"
    return unless @cbv_flow

    # Get the timeout setting
    session_timeout_limit = get_timeout_setting

    # Get the most recent activity timestamp
    last_active = get_last_activity_time

    # Calculate time until timeout
    time_until_timeout = [ session_timeout_limit - (Time.current - last_active), 0 ].max
    time_until_timeout_ms = time_until_timeout * 1000

    # Log detailed information for debugging
    Rails.logger.debug "Session for #{current_channel_identifier}: timeout_limit=#{session_timeout_limit}, last_active=#{last_active}, " +
                       "current=#{Time.current}, time_until_timeout=#{time_until_timeout}s"

    # Send warning when approaching timeout (5 minutes before)
    warning_threshold = 5.minutes.to_i * 1000
    warning_already_sent = connection.instance_variable_get(:@warning_sent_at)

    # Only send a warning if we're in the warning window AND
    # (we haven't sent a warning yet OR the previous warning was sent more than 1 minute ago)
    if time_until_timeout_ms <= warning_threshold && time_until_timeout_ms > 0 &&
       (warning_already_sent.nil? || Time.current - warning_already_sent > 1.minute)

      # Record that we sent a warning
      connection.instance_variable_set(:@warning_sent_at, Time.current)

      Rails.logger.info "Sending session timeout warning to #{current_channel_identifier}, #{time_until_timeout_ms / 1000} seconds remaining"

      broadcast_to(current_channel_identifier, {
        event: "session.warning",
        message: "Your session will expire soon",
        time_remaining_ms: time_until_timeout_ms
      })
    end

    # Debug info in development
    if Rails.env.development?
      broadcast_to(current_channel_identifier, {
        event: "session.debug",
        message: "Session activity check ran",
        time_remaining_ms: time_until_timeout_ms,
        last_activity: last_active.iso8601,
        timeout_in: session_timeout_limit.to_i,
        current_time: Time.current.iso8601,
        cbv_flow_id: @cbv_flow.id,
        warning_sent_at: connection.instance_variable_get(:@warning_sent_at)&.iso8601
      })
    end
  end
end
