class HealthCheckController < ActionController::Base
  def ok
    # keep the database connection alive
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok", version: ENV["IMAGE_TAG"] }
  end

  def solid_queue_ok
    if File.exist?(Rails.root.join("tmp/solid_queue.pid"))
      render plain: "OK", status: :ok
    else
      render plain: "PID file missing", status: :service_unavailable
    end
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
