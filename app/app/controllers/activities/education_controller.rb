class Activities::EducationController < Activities::BaseController
  include ActionController::Live

  def index
    session[:first_name] = params[:first_name],
    session[:last_name] = params[:last_name],
    session[:date_of_birth] = params[:date_of_birth]

    @stream_path = activities_flow_education_stream_path

    logger.info @stream_path
    logger.info session
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

    logger.info @student_information

    @schools = @student_information.schools.select do |school|
      logger.info school.most_recent_enrollment.semester_start
      logger.info school.most_recent_enrollment.current?
      school.most_recent_enrollment.current?
    end

    logger.info @schools

    @less_than_part_time = @schools.all? do |school|
      school.most_recent_enrollment.less_than_part_time?
    end

    logger.info @less_than_part_time
  end

  def confirm
    EducationActivity.create(
      identity_id: params[:identity_id],
      additional_comments: params[:additional_comments],
      credit_hours: params[:credit_hours],
      # TODO: remember how to do many to many
      # enrollment_activities_ids: params[:enrollment_ids].map { |id| },
    )
    redirect_to activities_flow_root_path
  end

  def start
    identity = current_identity
    service = EducationService.new
    failed = false

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Last-Modified"] = Time.now.httpdate

    sse = SSE.new(response.stream, event: "message")
    begin
      service.create_schools!(identity)
      sse.write(
        sync_indicator_update("school", :succeeded, I18n.t(".school")),
      )
    rescue Exception => e
      failed = true
      sse.write(
        sync_indicator_update("school", :failed, I18n.t(".school")),
      )
    end

    begin
      service.create_enrollments!(identity)
      sse.write(
        sync_indicator_update("enrollment", :succeeded, I18n.t(".enrollments")),
      )
    rescue Exception => e
      failed = true
      sse.write(
        sync_indicator_update("enrollment", :failed, I18n.t(".enrollments")),
      )
    end

    if failed
      redirect_path = activities_flow_root_path(
        first_name: identity.first_name,
        last_name: identity.last_name,
        date_of_birth: identity.date_of_birth,
        alert: "Failed to fetch education data"
      )
    else
      redirect_path = activities_flow_education_success_path(
        first_name: identity.first_name,
        last_name: identity.last_name,
        date_of_birth: identity.date_of_birth,
      )
    end

    sse.write(
      turbo_stream.action(:redirect, redirect_path)
    )
  ensure
    sse.close if sse
  end

  private

  def sync_indicator_update(name, status, content)
    turbo_stream.replace(
        name,
        html: view_context.render(
          SynchronizationIndicatorComponent.new(name: name, status: status).with_content(
            content
          )
        )
      )
  end
end
