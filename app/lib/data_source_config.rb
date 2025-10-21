class DataSourceConfig
  class DataSource
    attr_reader :id
    attr_reader :redirect_url

    def initialize(attrs = {})
      @description = attrs[:description]
      @id = attrs[:id]
      @redirect_url = attrs[:redirect_url]
    end

    def description(locale)
      @description
    end
  end

  attr_reader :sources

  def initialize
    @sources = [
      DataSource.new(
        id: "source1",
        description: "Gather some education information",
        redirect_url: "http://localhost:3001/",
      ),
      DataSource.new(
        id: "source2",
        description: "Gather some volunteering information",
        redirect_url: "http://localhost:3002/",
      )
    ]
  end
end
