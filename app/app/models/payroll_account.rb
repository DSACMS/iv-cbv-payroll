class PayrollAccount < ApplicationRecord
  def self.sti_name
    # "PayrollAccount::Pinwheel" => "pinwheel"
    name.demodulize.downcase
  end

  def self.sti_class_for(type_name)
    # "pinwheel" => PayrollAccount::Pinwheel
    PayrollAccount.const_get(type_name.capitalize)
  end

  belongs_to :cbv_flow

  after_update_commit {
    I18n.with_locale(cbv_flow.cbv_flow_invitation.language) do
      broadcast_replace target: self, partial: "cbv/synchronizations/indicators", locals: { pinwheel_account: self }
    end
  }
end
