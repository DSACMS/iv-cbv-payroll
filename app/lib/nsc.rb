module Nsc
  def self.disabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("NSC_DISABLED", "true"))
  end

  def self.enabled?
    !disabled?
  end
end
