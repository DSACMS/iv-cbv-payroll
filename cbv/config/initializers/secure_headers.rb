SecureHeaders::Configuration.default do |config|
  # CSP settings are handled by Rails
  # see: content_security_policy.rb
  config.csp = SecureHeaders::OPT_OUT
end
