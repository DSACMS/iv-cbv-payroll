# Be sure to restart your server when you modify this file.

# Configure parameters to be filtered from the log file. Use this to limit dissemination of
# sensitive information. See the ActiveSupport::ParameterFilter documentation for supported
# notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  # CBV flow invitation
  :email_address, :case_number, :first_name, :middle_name, :last_name,
  :snap_application_date, :agency_id_number, :client_id_number, :beacon_id,
  # CBV flow
  :additional_information
]
