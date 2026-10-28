class HealthCheckController < ActionController::Base
  def ok
    # keep the database connection alive
    ActiveRecord::Base.connection.execute("SELECT 1")
    # `ref` is the deployed image tag (a git SHA) and is consumed by
    # bin/will-deploy; `version` is the semantic version from version.txt.
    render json: { status: "ok", ref: ENV["IMAGE_TAG"], version: EmmyVersion.current }
  end

  def test_queueing
    # adding a second database query to distinguish healthiness of using one query vs another
    random_id = CbvFlow.last&.id || 10000
    TestQueueingJob.perform_later(Random.new.rand(1..random_id))
    render json: { status: "ok" }
  end

  def test_rendering
    return head :not_found unless Rails.env.development?

    respond_to do |format|
      format.html do
        render inline: "Missing .pdf extension in the URL!"
      end
      format.pdf do
        html = render_to_string(template: "health_check/test_rendering", formats: [ :pdf ], layout: "pdf")
        send_data PdfRenderer.render(html), filename: "test_rendering.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end
end
