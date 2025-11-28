class Activities::EducationController < ApplicationController
  include ActionController::Live

  class StudentInformation
    attr_accessor :first_name, :last_name, :date_of_birth
  end

  class SchoolInformation
    attr_accessor :name, :address
  end

  class EnrollmentInformation
    attr_accessor :most_recent_semester, :enrollment_status

    def less_than_part_time?
      true
    end
  end

  def index
    @stream_path = activities_flow_education_stream_path(
      first_name: params[:first_name],
      last_name: params[:last_name],
      date_of_birth: params[:date_of_birth]
    )
  end

  def show
    @student_information = StudentInformation.new
    @student_information.first_name = "jake"
    @student_information.last_name = "shilling"
    @student_information.date_of_birth = "4/27/1990"

    @school_information = SchoolInformation.new
    @school_information.name = "U of MD"
    @school_information.address = "123 Main St"

    @enrollment_information = EnrollmentInformation.new
    @enrollment_information.most_recent_semester = "Fall 2024"
    @enrollment_information.enrollment_status = "Part Time"
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
