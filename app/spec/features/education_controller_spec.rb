require "rails_helper"
require 'capybara/rspec'

class TestIdentityService
  def initialize(identity)
    @identity = identity
  end

  def read_identity
    @identity
  end

  def save_identity(_)
    @identity
  end
end

class TestEducationService
  def create_schools!(identity)
    identity.save
  end

  def create_enrollments!(identity)
    identity.save
  end
end

RSpec.feature "Education Flow", type: :feature do
  after { reset_session! }

  scenario "Education data has been collected" do
    enrollment = build(:enrollment, :current)
    school = build(:school, enrollments: [ enrollment ])
    identity = build(:identity, schools: [ school ])

    allow(IdentityService).to receive(:new).and_return(TestIdentityService.new(identity))
    allow(EducationService).to receive(:new).and_return(TestEducationService.new)

    visit activities_flow_education_root_path(
            identity: identity.attributes
          )

    expect(page).to have_current_path(activities_flow_education_success_path, wait: 3)

    expect(page).to have_text(identity.first_name)
    expect(page).to have_text(identity.last_name)
    expect(page).to have_text(identity.date_of_birth)

    expect(page).to have_text(school.name)
    expect(page).to have_text(school.address)

    expect(page).to have_text(enrollment.semester_start)

    click_button(
      I18n.t('activities.education.show.continue')
    )

    expect(page).to have_current_path(activities_flow_root_path, wait: 3)
    expect(page).to have_text(school.name)
  end
end
