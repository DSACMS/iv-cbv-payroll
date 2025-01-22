module Middleware
  class AddCrossOriginOpenerPolicy
    COOP_HEADER = "Cross-Origin-Opener-Policy"

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)
      headers[COOP_HEADER] = "same-origin" unless headers.key?(COOP_HEADER)
      [ status, headers, response ]
    end
  end
end
