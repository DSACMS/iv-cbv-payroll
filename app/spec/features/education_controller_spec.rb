require "rails_helper"

RSpec.feature "Education confirmation page", type: :feature do
  context "education data has been collected" do
    let (:enrollment) { build(:enrollment, :current) }
    let (:school) { build(:school, enrollments: [ enrollment ]) }

    let(:identity) { create(:identity, schools: [ school ]) }

    before do
      visit activities_flow_education_success_path(
              first_name: identity.first_name,
              last_name: identity.last_name,
              date_of_birth: identity.date_of_birth
            )
    end

    it "displays student information" do
      expect(page).to have_text(identity.first_name)
      expect(page).to have_text(identity.last_name)
      expect(page).to have_text(identity.date_of_birth)
    end

    it "displays school information" do
      expect(page).to have_text(school.name)
      expect(page).to have_text(school.address)
    end

    it "displays enrollment information" do
      expect(page).to have_text(enrollment.semester_start)
      expect(page).to have_text(enrollment.status)
    end
  end
end
