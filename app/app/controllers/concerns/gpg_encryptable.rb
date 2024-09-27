require "gpgme"
require "tempfile"

module GpgEncryptable
  extend ActiveSupport::Concern

  def gpg_encrypt_file(file_path, public_key)
    crypto = GPGME::Crypto.new
    begin
      key_fingerprint = imported_key_fingerprint(public_key)
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

  def imported_key_fingerprint(public_key)
    import_result = GPGME::Key.import(public_key)
    import_result.imports.first.fingerprint
  end
end
