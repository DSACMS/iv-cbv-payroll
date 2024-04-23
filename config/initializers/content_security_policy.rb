# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.img_src :self, :data, "https://www.google-analytics.com"
    policy.object_src :none
    policy.script_src :self, "https://js-agent.newrelic.com", "https://*.nr-data.net", "https://dap.digitalgov.gov", "https://www.google-analytics.com"
    policy.connect_src :self, "https://*.nr-data.net", "https://dap.digitalgov.gov", "https://www.google-analytics.com"
    # 'unsafe-inline' is needed because Turbo uses inline CSS for at least the progress bar
    policy.style_src :self, "'unsafe-inline'"
  end

  #
  #   # Generate session nonces for permitted importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
  #
  #   # Report violations without enforcing the policy.
  #   # config.content_security_policy_report_only = true
end
