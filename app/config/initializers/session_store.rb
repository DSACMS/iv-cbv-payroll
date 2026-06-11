# end to end tests require no auth of session length--TODO fix
unless Rails.env.test?
  Rails.application.config.session_store :cookie_store,
                                         key: "_iv_cbv_payroll_session",
                                         expire_after: Rails.application.config.cbv_session_expires_after
end
