class Activities::EducationController < ApplicationController
  include ActionController::Live

  def index
    @stream_path = activities_flow_education_stream_path(
      first_name: params[:first_name],
      last_name: params[:last_name],
      date_of_birth: params[:date_of_birth]
    )
  end

  def show
    @student_information = Identity.find_by(
      first_name: params[:first_name],
      last_name: params[:last_name],
      date_of_birth: params[:date_of_birth],
    )

    unless @student_information
      redirect_to(
        activities_flow_root_path,
        flash: { alert: t("activities.education.error_no_data") }
      )
    end

    @schools = @student_information.schools.select do |school|
      school.most_recent_enrollment.current?
    end

    @less_than_part_time = @schools.all? do |school|
      school.most_recent_enrollment.less_than_part_time?
    end
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
