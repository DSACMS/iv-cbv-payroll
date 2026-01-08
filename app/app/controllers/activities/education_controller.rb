class Activities::EducationController < Activities::BaseController
  include ActionController::Live

  def new
  end

  def show
    @education_activity = EducationActivity.find_by(
      id: params[:education_activity_id],
      activity_flow_id: @flow.id
    )

    @student_information = current_identity!
    unless @education_activity
      redirect_to(
        activities_flow_root_path,
        flash: { alert: t("activities.education.error_no_data") }
      )
    end
  end

  def create
    education_params = params.require(
      :education_activity
    ).permit(:id, :additional_comments, :credit_hours)

    id = education_params[:id]

    activity = EducationActivity.find_by(
      {
        id: id,
        activity_flow_id: @flow.id
      }
    )

    if activity
      activity.update(
        education_params.merge({ confirmed: true })
      )
      activity.save

      redirect_to activities_flow_root_path, notice: t("activities.education.created")
    else
      render :new, alert: t("activities.education.error_no_data")
    end
  end

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Last-Modified"] = Time.now.httpdate

    sse = SSE.new(response.stream, event: "message")

    begin
      nsc_service = Aggregators::Sdk::NscService.new(environment: nsc_environment)

      activity = nsc_service.call(@flow) do
        sse.write(
          sync_indicator_update("student_info", :in_progress)
        )
      end

      sse.write(
        sync_indicator_update("student_info", :succeeded)
      )

      # Sends success message to the loading page, with redirect
      sse.write(
        { status: "succeeded", message: activities_flow_education_path(params: { education_activity_id: activity.id }) },
        event: "education_result"
      )

    rescue Aggregators::Sdk::NscService::ApiError => e
      sse.write(
        sync_indicator_update("student_info", :failed)
      )

      sse.write(
        turbo_stream.action(:redirect, activities_flow_education_error_path(params: { error_code: e.code, error_message: e.message }))
      )

    rescue Faraday::TimeoutError => e
      sse.write(
        sync_indicator_update("student_info", :failed)
      )

      sse.write(
        turbo_stream.action(:redirect, activities_flow_education_error_path(params: { error_code: "TIMEOUT", error_message: t("activities.education.errors.timeout") }))
      )
    rescue StandardError => e
      Rails.logger.error("Education API error: #{e.message}")

      sse.write(
        sync_indicator_update("student_info", :failed)
      )

      sse.write(
        turbo_stream.action(:redirect, activities_flow_education_error_path(params: { error_code: "UNEXPECTED_ERROR", error_message: t("activities.education.errors.unexpected") }))
      )
    end
  ensure
    sse.close if sse
  end

  def error
    @error_code = params[:error_code]
    @error_message = params[:error_message]
  end

  private

  def nsc_environment
    ENV.fetch("NSC_ENVIRONMENT", "sandbox").to_sym
  end

  def sync_indicator_update(name, status)
    turbo_stream.replace(
        name,
        html: view_context.render(
          SynchronizationIndicatorComponent.new(name: name, status: status).with_content(
            I18n.t("activities.education.new.#{name}")
          )
        )
      )
  end
end
