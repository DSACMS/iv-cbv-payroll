class Uswds::IconList < ViewComponent::Base
  class Item < ViewComponent::Base
    attr_reader :icon

    def initialize(icon:)
      @icon = icon
    end
  end

  renders_many :items, Item
end
