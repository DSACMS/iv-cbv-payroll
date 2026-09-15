module Nsc
  def self.disabled?
    ENV.fetch("NSC_DISABLED", true)
  end

  def self.enabled?
    !disabled?
  end
end
