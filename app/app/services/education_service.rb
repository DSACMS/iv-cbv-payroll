# Abstracts deriving education data from an {Identity}
class EducationService
  # Mocks the education data retrieval process for local development
  class LocalEducationService
    def self.create_schools!(identity)
      Rails.logger.info "Pretending to look up school information"

      School.where(identity: identity).destroy_all
      self.create_school(identity)

      sleep 2
    end

    def self.create_enrollments!(identity)
      Rails.logger.info "Pretending to look up enrollment information"

      identity.schools.map do |school|
        self.create_enrollment(school)
      end

      sleep 2
    end

    private

    def self.create_school(identity)
      require "faker"

      identity.schools.create(
        name: Faker::University.name,
        address: Faker::Address.full_address,
        identity_id: identity.id,
      )
      identity.save
    end

    def self.create_enrollment(school)
      require "faker"

      school.enrollments.create!(
        status: [ :full_time, :part_time, :quarter_time ].sample,
        semester_start: Faker::Date.in_date_period(
          month: Date.today.month > 6 ? 8 : 2,
          year: Date.today.year
        ),
        school_id: school.id
      )
      school.save
    end
  end

  # Sets up the appropriate internal implementation based on the
  # current environment.
  #
  # @raise [NotImplementedError] When the current `Rails.env` does not
  #   have an appropriate implementation
  def initialize
    if Rails.env.local?
      @impl = LocalEducationService
    else
      raise NotImplementedError
    end
  end

  # Searches for schools by this {Identity} and saves them to the database
  #
  # @params identity [Identity] The identity to search for. This object will
  #   be saved if it has not already been.
  # @return [void]
  def create_schools!(identity)
    @impl.create_schools!(identity)
  end

  # Searches for enrollments by this {Identity} and saves them to the database
  #
  # @params identity [Identity] The identity to search for. This object will
  #   be saved if it has not already been.
  # @return [void]
  def create_enrollments!(identity)
    @impl.create_enrollments!(identity)
  end
end
