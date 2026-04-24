# frozen_string_literal: true

class ActivityFlowHeaderComponent < ViewComponent::Base
  attr_reader :title, :exit_url, :back_url

  def initialize(title:, exit_url:, back_url: nil)
    @title = title
    @exit_url = exit_url
    @back_url = back_url
  end

  def confirm_on_exit?
    helpers.params[:from_edit].blank?
  end
end
