# frozen_string_literal: true

class TableCellComponent < ViewComponent::Base
  def initialize(class_names: nil, is_header: false)
    @class_names = class_names
    @is_header = is_header
  end

  def call
    tag_type = @is_header? :th : :td
    content_tag tag_type, content, class: @class_names
  end
end
