module Nsc
  OVERRIDE_CACHE_KEY = "nsc_disabled_override"

  def self.disabled?
    override = Rails.cache.read(OVERRIDE_CACHE_KEY)
    return override unless override.nil?

    ENV.fetch("NSC_DISABLED", "true") == "true"
  end

  def self.enabled?
    !disabled?
  end

  def self.override!(disabled)
    Rails.cache.write(OVERRIDE_CACHE_KEY, disabled)
  end

  def self.clear_override!
    Rails.cache.delete(OVERRIDE_CACHE_KEY)
  end
end
