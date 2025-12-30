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

  def destroy
    activity = @flow.education_activities.find(params[:education_activity_id])
    activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.education.deleted")
  end

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Last-Modified"] = Time.now.httpdate

    sse = SSE.new(response.stream, event: "message")

    # This is just to show how we can send updates to change the indicators
    call_count = 0
    indicators = [ "school", "enrollment", "hours" ]
    activity = EducationService.new(@flow).call do
      indicator = indicators[call_count % indicators.count]
      sse.write(
        sync_indicator_update(indicator, :succeeded)
      )
      call_count += 1
    end

    sse.write(
      turbo_stream.action(:redirect, activities_flow_education_path(params: { education_activity_id: activity.id }))
    )
  ensure
    sse.close if sse
  end

  private

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
