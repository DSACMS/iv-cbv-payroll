module Nsc
  def self.disabled?
    ENV.fetch("NSC_DISABLED", "true") == "true"
  end

  def self.enabled?
    !disabled?
  end
end
