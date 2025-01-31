class CreateApiAccessTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :api_access_tokens do |t|
      t.string :access_token_digest
      t.integer :user_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
