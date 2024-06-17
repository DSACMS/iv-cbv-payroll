class AddPgcryptoExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto'
  end
end
