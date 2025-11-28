require 'rails_helper'

RSpec.describe School, type: :model do
  let(:active_enrollments) { build_list(:enrollment, 5, :current) }
  let(:inactive_enrollments) { build_list(:enrollment, 5, :not_current) }
  let(:enrollments) { active_enrollments.concat inactive_enrollments }

  let(:most_recent_enrollment) do
    enrollments.max_by(&:semester_start)
  end

  let(:school) { create(:school, enrollments: enrollments) }

  describe "#current_enrollments" do
    it "includes active enrollments" do
      expect(school.current_enrollments).to all(be_current)
    end
  end

  describe "#most_recent_enrollment" do
    it "returns the single most recent enrollment" do
      expect(
        school.most_recent_enrollment
      ).to eq(most_recent_enrollment)
    end
  end
end
