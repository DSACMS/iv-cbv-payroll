require "gpgme"
require "tempfile"

module GpgEncryptable
  extend ActiveSupport::Concern

  def gpg_encrypt_file(file_path, public_key)
    crypto = GPGME::Crypto.new
    begin
      key_fingerprint = import_key_if_not_exists(public_key)
      recipients = GPGME::Key.find(:public, key_fingerprint)
      raise "Recipient key not found" if recipients.empty?

      encrypted_tempfile = Tempfile.new(%w[encrypted .gpg])
      encrypted_tempfile.binmode

      File.open(file_path, "rb") do |input|
        Rails.logger.info "Encrypting file: #{file_path}"
        crypto.encrypt(input, recipients: recipients, output: encrypted_tempfile, always_trust: true)
        if encrypted_tempfile.path != nil
          Rails.logger.info "Encrypted file: #{encrypted_tempfile.path}"
        else
          Rails.logger.error "Failed to encrypt file: #{file_path}"
          raise "Encryption failed: Output file not created"
        end
      end

      encrypted_tempfile.rewind
      encrypted_tempfile
    rescue GPGME::Error => e
      Rails.logger.error "GPG encryption failed: #{e.message}"
      raise
    end
  end

  private
  def import_key_if_not_exists(public_key)
    # Extract the fingerprint from the public key
    imported_keys = GPGME::Key.find(public_key, "MA MOVEit")
    raise "Failed to import public key" if imported_keys.empty?

    fingerprint = imported_keys.first.fingerprint

    # Check if the key already exists
    existing_keys = GPGME::Key.find(:public, fingerprint)
    if existing_keys.empty?
      # Import the key if it does not exist
      GPGME::Key.import(public_key)
    else
      Rails.logger.info "Key with fingerprint #{fingerprint} already exists"
    end

    fingerprint
  end
end
