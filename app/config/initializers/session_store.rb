Rails.application.config.session_store :cookie_store,
  key: "_iv_cbv_payroll_session",
  expire_after: Rails.application.config.cbv_session_expires_after
