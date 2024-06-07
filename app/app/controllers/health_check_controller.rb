class HealthCheckController < ActionController::Base
  def ok
    render json: { status: "ok", version: ENV["IMAGE_TAG"] }
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
