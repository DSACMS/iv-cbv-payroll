class SessionChannel < ApplicationCable::Channel
  # Check session activity every minute
  periodically :check_session_activity, every: 60.seconds

  def subscribed
    identifier = current_user || connection.session[:cbv_flow_id] || connection.session.id
    stream_for identifier
    
    # Record connection time
    connection.instance_variable_set(:@session_channel_connected_at, Time.current)
    
    # Send session info to client
    transmit_session_info
  end
  
  def received(data)
    # This is called whenever data is received from the client
    # We can use this to track user activity at the websocket level
    Rails.logger.debug "Data received on SessionChannel: #{data}"
    
    # Update last activity time
    connection.instance_variable_set(:@session_channel_last_activity, Time.current)
  end

  # Send current session information to the client
  def transmit_session_info
    identifier = current_user || connection.session[:cbv_flow_id] || connection.session.id
    
    if current_user && current_user.respond_to?(:last_request_at) && current_user.last_request_at
      # For authenticated users, use Devise timeout (default 30 minutes)
      timeout_in = defined?(Devise) && Devise.respond_to?(:timeout_in) ? Devise.timeout_in : 30.minutes
      last_active = current_user.last_request_at || Time.current
      time_until_timeout = [timeout_in - (Time.current - last_active), 0].max
      
      transmit({
        event: "session.info",
        timeout_in_ms: timeout_in * 1000,
        time_remaining_ms: time_until_timeout * 1000,
        last_activity: last_active.iso8601
      })
    elsif connection.session[:cbv_flow_id].present?
      # For CBV flow, use 30 minute timeout
      transmit({
        event: "session.info",
        timeout_in_ms: 30.minutes * 1000,
        time_remaining_ms: 30.minutes * 1000,
        last_activity: Time.current.iso8601
      })
    end
  end

  private

  def check_session_activity
    identifier = current_user || connection.session[:cbv_flow_id] || connection.session.id
    return unless identifier
    
    # Get last activity time either from the connection or from the user's last_request_at
    last_activity = connection.instance_variable_get(:@session_channel_last_activity)
    
    if current_user && current_user.respond_to?(:last_request_at) && current_user.last_request_at
      # For authenticated users, use Devise timeout (default 30 minutes)
      timeout_in = defined?(Devise) && Devise.respond_to?(:timeout_in) ? Devise.timeout_in : 30.minutes
      last_active = [last_activity, current_user.last_request_at].compact.max || Time.current
      time_until_timeout = [timeout_in - (Time.current - last_active), 0].max
      Rails.logger.debug "User #{current_user.id} session expires in #{time_until_timeout} seconds"
    else
      # For CBV flow, use session timeout (30 minutes)
      timeout_in = 30.minutes
      connection_time = connection.instance_variable_get(:@session_channel_connected_at) || Time.current
      last_active = last_activity || connection_time
      time_until_timeout = [timeout_in - (Time.current - last_active), 0].max
    end

    # Convert to milliseconds for JavaScript
    time_until_timeout_ms = time_until_timeout * 1000

    # Send warning when approaching timeout (5 minutes before)
    warning_threshold = 5.minutes.to_i * 1000
    if time_until_timeout_ms <= warning_threshold && time_until_timeout_ms > 0
      broadcast_to(identifier, {
        event: "session.warning",
        message: "Your session will expire soon",
        time_remaining_ms: time_until_timeout_ms
      })
    end
  end
end 