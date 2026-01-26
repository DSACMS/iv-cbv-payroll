require 'rails_helper'

RSpec.describe EducationActivity, type: :model do
  describe "#display_status" do
    it 'returns "Enrolled" for enrolled status' do
      activity = described_class.new(
        status: :succeeded
      )

      expect(activity.display_status).to eq(
        I18n.t(
          'activities.education.enrollment_status.succeeded',
        )
      )
    end

    it 'returns "Not Enrolled" for not enrolled status' do
      activity = described_class.new(
        status: :no_enrollments
      )

      expect(activity.display_status).to eq(
        I18n.t(
          'activities.education.enrollment_status.no_enrollments',
        )
      )
    end

    it 'returns "N/A" for unknown status' do
      activity = described_class.new(
        status: :unknown
      )

      expect(activity.display_status).to eq(
        I18n.t(
          'activities.education.enrollment_status.unknown',
        )
      )
    end
  end
end
