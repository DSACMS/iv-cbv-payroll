# frozen_string_literal: true

class ActivityFlowHeaderComponent < ViewComponent::Base
  attr_reader :title, :exit_url, :back_url, :track_event_prefix

  def initialize(title:, exit_url:, back_url: nil, track_event_prefix: nil)
    @title = title
    @exit_url = exit_url
    @back_url = back_url
    @track_event_prefix = track_event_prefix
  end

  def confirm_on_exit?
    helpers.params[:from_edit].blank?
  end
end
