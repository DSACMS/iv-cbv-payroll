class Api::SessionsController < ApplicationController
  # Skip CSRF protection for API calls if you're using protect_from_forgery
  # skip_before_action :verify_authenticity_token, only: [:extend]
  
  def extend
    Rails.logger.info "API::SessionsController#extend called"
    
    # Reset the Devise timeout timer
    request.env['devise.skip_timeout'] = true
    
    if current_user
      Rails.logger.info "Current user found: #{current_user.id}"
      current_user.remember_me! if current_user.respond_to?(:remember_me!)
      current_user.remember_me = true if current_user.respond_to?(:remember_me=)
      
      # Update the last_request_at timestamp to extend the Devise timeout
      if current_user.respond_to?(:update_tracked_fields!)
        current_user.update_tracked_fields!(request)
      end
      
      # Force sign in to reset the Devise timeout
      sign_in(current_user, force: true)
      
      respond_to do |format|
        format.json { 
          Rails.logger.info "Responding with JSON"
          render json: { success: true, message: "Session extended successfully" } 
        }
        format.html { 
          Rails.logger.info "Responding with HTML redirect"
          redirect_back(fallback_location: root_path) 
        }
        format.any { 
          Rails.logger.info "Responding with 406 Not Acceptable"
          head :not_acceptable 
        }
      end
    elsif session[:cbv_flow_id].present?
      # Handle CBV flow session extension
      Rails.logger.info "Extending session for CBV flow: #{session[:cbv_flow_id]}"
      
      # Reset the session timestamp
      request.env["rack.session.options"][:expire_after] = 30.minutes
      
      respond_to do |format|
        format.json { 
          Rails.logger.info "Responding with JSON for CBV flow"
          render json: { success: true, message: "Session extended successfully" } 
        }
        format.html { 
          Rails.logger.info "Responding with HTML redirect for CBV flow"
          redirect_back(fallback_location: root_path) 
        }
        format.any { 
          Rails.logger.info "Responding with 406 Not Acceptable for CBV flow"
          head :not_acceptable 
        }
      end
    else
      Rails.logger.warn "No current user or CBV flow found"
      respond_to do |format|
        format.json { render json: { success: false, error: "No active session" }, status: :unauthorized }
        format.html { redirect_to new_user_session_path }
        format.any { head :unauthorized }
      end
    end
  rescue => e
    Rails.logger.error "Error in extend session: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :internal_server_error }
      format.html { redirect_to root_path, alert: "An error occurred while extending your session." }
      format.any { head :internal_server_error }
    end
  end
end 