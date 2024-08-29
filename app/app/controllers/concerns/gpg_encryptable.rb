require "gpgme"

module GpgEncryptable
  extend ActiveSupport::Concern

  included do
    attr_accessor :public_key
  end

  def gpg_encrypt_file(file_path, public_key)
    # import_key(public_key)
    crypto = GPGME::Crypto.new
    recipient = GPGME::Key.find(:public, public_key).first
    encrypted_file_path = "#{file_path}.gpg"

    File.open(encrypted_file_path, "wb") do |output|
      crypto.encrypt File.open(file_path, "rb"), recipients: recipient, output: output
    end

    encrypted_file_path
  end

  private

  def import_key(key_data)
    unless GPGME::Key.valid?(key_data)
      raise "Invalid GPG key: The provided key data is not valid"
    end
    GPGME::Key.import(key_data)
  end
end
