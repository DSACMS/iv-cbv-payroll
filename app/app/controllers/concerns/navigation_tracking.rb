# Extends Trackable's attributes for activity steps; hub-level events don't use this navigation context.
module NavigationTracking
  extend ActiveSupport::Concern

  private

  def standard_track_attributes
    super.merge(
      from_edit: params[:from_edit].presence,
      from_review: params[:from_review].presence
    )
  end
end
