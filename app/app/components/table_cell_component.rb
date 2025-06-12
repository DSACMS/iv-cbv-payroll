# frozen_string_literal: true

class TableCellComponent < ViewComponent::Base
  def initialize(class_names: nil, is_header: false, colspan: nil, data_label: nil, scope: nil)
    @class_names = class_names
    @is_header = is_header
    @colspan = colspan
    @data_label = data_label
    @scope = scope
  end

  def call
    tag_type = @is_header? :th : :td
    content_tag tag_type, content, scope: @scope, data: { label: @data_label }, class: @class_names, colspan: @colspan
  end
end
