class AddIdentityToActivityFlow < ActiveRecord::Migration[7.2]
  def change
    add_reference :activity_flows, :identity, null: true, foreign_key: true
  end
end
