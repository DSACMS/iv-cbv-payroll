# frozen_string_literal: true

class ActivityFlowHeaderComponent < ViewComponent::Base
  attr_reader :title, :exit_url, :back_url, :always_confirm

  def initialize(title:, exit_url:, back_url: nil, always_confirm: false)
    @title = title
    @exit_url = exit_url
    @back_url = back_url
    @always_confirm = always_confirm
  end
end
