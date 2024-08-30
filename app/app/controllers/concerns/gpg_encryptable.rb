require "gpgme"

module GpgEncryptable
  extend ActiveSupport::Concern

  def gpg_encrypt_file(file_path, public_key)
    crypto = GPGME::Crypto.new
    recipient = GPGME::Key.find(:public, public_key).first
    encrypted_file_path = "#{file_path}.gpg"

    File.open(encrypted_file_path, "wb") do |output|
      File.open(file_path, "rb") do |input|
        crypto.encrypt input, recipients: recipient, output: output
      end
    end

    encrypted_file_path
  end
end
