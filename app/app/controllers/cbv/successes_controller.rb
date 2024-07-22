class Cbv::SuccessesController < Cbv::BaseController
  helper_method :generate_confirmation_number

  def show
    if @cbv_flow.confirmation_number.blank?
      @cbv_flow.update(confirmation_number: generate_confirmation_number)
    end
    render :show
  end

  private

  def generate_confirmation_number(prefix = nil)
    if(@cbv_flow.confirmation_number.blank?)
      @cbv_flow.update(confirmation_number: confirmation_number)
    end
    confirmation_number = "#{@cbv_flow.id}-#{Time.now.to_i.to_s(36)}"
    prefix.present? ? "#{prefix}-#{confirmation_number}" : confirmation_number
  end
end
