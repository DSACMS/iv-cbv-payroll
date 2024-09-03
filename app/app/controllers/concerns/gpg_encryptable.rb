require "gpgme"
require "tempfile"

module GpgEncryptable
  extend ActiveSupport::Concern

  def gpg_encrypt_file(file_path, public_key)
    crypto = GPGME::Crypto.new
    begin
      recipient = GPGME::Key.find(:public, public_key)
      raise "Recipient key not found" if recipient.nil?

      encrypted_tempfile = Tempfile.new(%w[encrypted .gpg])
      encrypted_tempfile.binmode

      File.open(file_path, "rb") do |input|
        File.open(encrypted_tempfile.path, "wb") do |output|
          crypto.encrypt input, recipients: recipient, output: output
        end
      end

      encrypted_tempfile.rewind
      encrypted_tempfile
    rescue GPGME::Error => e
      Rails.logger.error "GPG encryption failed: #{e.message}"
      raise
    end
  end
end
