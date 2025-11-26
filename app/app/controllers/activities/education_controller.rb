class Activities::EducationController < ApplicationController
  include ActionController::Live

  def index
    @stream_path = activities_flow_education_stream_path(
      first_name: params[:first_name],
      last_name: params[:last_name],
      date_of_birth: params[:date_of_birth]
    )
  end

  def start
    service = EducationService.new

    first_name = params[:first_name]
    last_name = params[:last_name]
    date_of_birth = params[:date_of_birth]

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Last-Modified"] = Time.now.httpdate

    sse = SSE.new(response.stream, event: "message")
    service.search_for_schools(
      first_name: first_name,
      last_name: last_name,
      date_of_birth: date_of_birth
    )
    sse.write("succeeded", event: "school")

    service.search_for_schools(
      first_name: first_name,
      last_name: last_name,
      date_of_birth: date_of_birth
    )
    sse.write("succeeded", event: "enrollment")

    service.search_for_schools(
      first_name: first_name,
      last_name: last_name,
      date_of_birth: date_of_birth
    )
    sse.write("succeeded", event: "hours")
  ensure
    sse.close if sse
  end
end
