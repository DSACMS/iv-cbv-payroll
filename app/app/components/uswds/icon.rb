# Decorative icon; the surrounding control or content supplies its accessible name.
class Uswds::Icon < ViewComponent::Base
  def initialize(name:)
    @name = name
  end
end
