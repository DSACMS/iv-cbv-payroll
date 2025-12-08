# Abstracts deriving education data from an {Identity}
class EducationService
  # Mocks the education data retrieval process for local development
  class LocalEducationService
    def self.call(activity_flow)
      # Add pretend flow


      # send update messages (three progress updates)
      sleep 2
      yield if block_given?
      sleep 2
      yield if block_given?
      sleep 2
      yield if block_given?

      EducationActivity.create!(
        status: [ :full_time, :part_time, :quarter_time ].sample,
        school_name: Faker::University.name,
        school_address: Faker::Address.full_address,
        activity_flow: activity_flow
      )
    end
  end

  # Sets up the appropriate internal implementation based on the
  # current environment.
  #
  # @param [ActivityFlow] activity_flow
  #
  # @raise [NotImplementedError] When the current `Rails.env` does not
  #   have an appropriate implementation
  def initialize(activity_flow)
    @activity_flow = activity_flow
    if Rails.env.local?
      @impl = LocalEducationService
    else
      raise NotImplementedError
    end
  end

  def call(&block)
    @impl.call(@activity_flow, &block)
  end
end
