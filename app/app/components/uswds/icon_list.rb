class Uswds::IconList < ViewComponent::Base
  class Item < ViewComponent::Base
    attr_reader :icon

    def initialize(icon:)
      @icon = icon
    end

    def call
      content
    end
  end

  renders_many :items, Item

  def initialize(class_names: "margin-top-2", item_class_names: "margin-bottom-1 display-flex flex-align-center")
    @class_names = class_names
    @item_class_names = item_class_names
  end

  private

  attr_reader :class_names, :item_class_names
end
