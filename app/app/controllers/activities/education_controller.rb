class Activities::EducationController < ApplicationController
  include ActionController::Live

  class EducationState
    attr_accessor :school, :enrollment, :hours

    def initialize
      @school = :in_progress
      @enrollment = :in_progress
      @hours = :in_progress
    end
  end

  def index
    @state = EducationState.new
  end

  def start
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Last-Modified"] = Time.now.httpdate

    sse = SSE.new(response.stream, event: "message")

    sleep 2
    sse.write("succeeded", event: "school")
    sleep 2
    sse.write("succeeded", event: "enrollment")
    sleep 2
    sse.write("succeeded", event: "hours")
  ensure
    sse.close
  end
end
