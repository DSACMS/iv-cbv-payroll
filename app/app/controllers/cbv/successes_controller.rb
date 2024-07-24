class Cbv::SuccessesController < Cbv::BaseController
  helper_method :confirmation_number

  def show
    if @cbv_flow.confirmation_number.blank?
      confirmation_number = generate_confirmation_number(@cbv_flow.site_id)
      @cbv_flow.update(confirmation_number: confirmation_number)
    end
    render :show
  end

  private

  def confirmation_number
    @cbv_flow["confirmation_number"]
  end

  def generate_confirmation_number(prefix = nil)
    [
      prefix,
      (Time.now.to_i % 36 ** 3).to_s(36).upcase.tr("OISB", "0158").rjust(3, "0"),
      @cbv_flow.id.to_s.rjust(4, "0")
    ].compact.join
  end
end
