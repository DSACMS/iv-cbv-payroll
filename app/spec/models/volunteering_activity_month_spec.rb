require "rails_helper"

RSpec.describe VolunteeringActivityMonth, type: :model do
  it_behaves_like "an activity month model",
    parent_factory: :volunteering_activity,
    month_factory: :volunteering_activity_month,
    parent_association: :volunteering_activity
end
