# frozen_string_literal: true

class TableHeaderComponent < ViewComponent::Base
  attr_reader :colspan

  def initialize(colspan: 2, scope: "colgroup")
    @colspan = colspan
    @scope = scope
  end
end
