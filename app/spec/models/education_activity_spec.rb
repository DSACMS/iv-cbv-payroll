require 'rails_helper'

RSpec.describe EducationActivity, type: :model do
  describe "#display_status" do
    it 'returns full time string' do
       activity = EducationActivity.new(
         status: :full_time
       )

       expect(activity.display_status).to eq(
                                            I18n.t(
                                              'activities.education.enrollment_status.full_time',
                                            )
                                          )
     end
    it 'returns full time string' do
      activity = EducationActivity.new(
        status: :part_time,
      )

      expect(activity.display_status).to eq(
                                           I18n.t(
                                             'activities.education.enrollment_status.part_time',
                                           ))
    end
    it 'returns credit hours when less than part time' do
      activity = EducationActivity.new(
        status: :quarter_time,
        credit_hours: 3
      )

      expect(activity.display_status).to eq(
                                           I18n.t(
                                             'activities.education.enrollment_status.hours',
                                             count: 3
                                           ))
    end
  end
end
