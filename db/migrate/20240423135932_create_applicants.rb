class CreateApplicants < ActiveRecord::Migration[7.0]
  def change
    create_table :applicants do |t|

      t.timestamps
    end
  end
end
