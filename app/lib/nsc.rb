module Nsc
  def self.disabled?
    ENV["NSC_DISABLED"] == "true"
  end

  def self.enabled?
    !disabled?
  end
end
