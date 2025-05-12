class HealthCheckController < ActionController::Base
  def ok
    # keep the database connection alive
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok", version: ENV["IMAGE_TAG"] }
  end

  def test_ok
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
        render pdf: "test_rendering", inline: "<strong>The PDF <em>works</em>!</strong>"
      end
    end
  end
end
