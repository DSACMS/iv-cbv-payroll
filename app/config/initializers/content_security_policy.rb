# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# -----------------------------------------------------------------------------
# Be sure to restart your server when you modify this file!
# -----------------------------------------------------------------------------

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self
    policy.form_action :self, "https://login.microsoftonline.com"
    policy.frame_ancestors :self
    policy.img_src :self, :data, "https://*.cloudinary.com", "https://cdn.getpinwheel.com"
    policy.object_src :none
    policy.script_src :self, "https://js-agent.newrelic.com", "https://*.nr-data.net", "https://cdn.getpinwheel.com", "http://cdn.mxpnl.com"
    policy.connect_src :self, "https://*.nr-data.net", "https://api-js.mixpanel.com"
    policy.worker_src :self, "blob:"
    policy.frame_src :self, "https://cdn.getpinwheel.com"
    policy.style_src_elem :self
    # Allow inline styles as we have some on the payment_details page:
    policy.style_src_attr "'unsafe-inline'"
  end

  #
  #   # Generate session nonces for permitted importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src-elem]
  #
  #   # Report violations without enforcing the policy.
  #   # config.content_security_policy_report_only = true
end
