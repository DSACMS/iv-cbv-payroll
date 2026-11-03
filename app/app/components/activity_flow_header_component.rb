# frozen_string_literal: true

class ActivityFlowHeaderComponent < ViewComponent::Base
  attr_reader :title, :exit_url, :back_url, :track_event_prefix, :track_event_attributes

  def initialize(title:, exit_url: nil, back_url: nil, track_event_prefix: nil, track_event_attributes: {})
    @title = title
    @exit_url = exit_url
    @back_url = back_url
    @track_event_prefix = track_event_prefix
    @track_event_attributes = track_event_attributes
  end

  def confirm_on_exit?
    helpers.params[:from_edit].blank?
  end
end
