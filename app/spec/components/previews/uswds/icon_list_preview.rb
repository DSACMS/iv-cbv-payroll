# frozen_string_literal: true

module Uswds
  class IconListPreview < ApplicationPreview
    def default
      render(Uswds::IconList.new) do |icon_list|
        icon_list.with_item(icon: "attach_money").with_content("Income verification")
        icon_list.with_item(icon: "groups").with_content("Friends and family")
        icon_list.with_item(icon: "work").with_content("Job training program")
      end
    end
  end
end
