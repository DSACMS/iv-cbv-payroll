# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, "https://*.cloudinary.com"
    policy.form_action :self, "https://login.microsoftonline.com"
    policy.frame_ancestors :self
    policy.img_src :self, :data, "https://*.cloudinary.com", "https://cdn.getpinwheel.com"
    policy.object_src :none
    policy.script_src :self, *%w[
      https://js-agent.newrelic.com
      https://*.nr-data.net
      https://cdn.getpinwheel.com
      https://*.argyle.com
    ]
    policy.connect_src :self, "https://*.nr-data.net", "https://*.argyle.com"
    policy.worker_src :self, "blob:"
    policy.frame_src :self, "https://cdn.getpinwheel.com"

    # Allow <style> tags used by Aggregator SDKs by explicitly allowing their
    # hashes.
    #
    # When upgrading Pinwheel or Argyle JS SDKs, update these hashes by
    # attempting to open each modal. If the <style> tag has changed, and we
    # need to update the hash, then the JS console will show you the new hashes
    # when it blocks adding the <style> tag to the page.
    #
    # The error will say "Refused ... Either ... a hash ('sha256-[blahblah]') ...
    # is required." Replace the hash value(s) here from that message.
    policy.style_src :self,
      "'sha256-WAyOw4V+FqDc35lQPyRADLBWbuNK8ahvYEaQIYF1+Ps='", # Pinwheel
      "'sha256-8Fd8AAaNByYvS/HuItVFketOItMHf2YiH+wvh8OVQOA='", # Pinwheel
      "'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU='"  # Argyle
  end

  #
  #   # Generate session nonces for permitted importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
  #
  #   # Report violations without enforcing the policy.
  #   # config.content_security_policy_report_only = true
end
