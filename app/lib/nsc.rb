module Nsc
  def self.disabled?
    ActiveModel::Type::Boolean.new.cast(ENV["NSC_DISABLED"])
  end

  def self.enabled?
    !disabled?
  end
end
