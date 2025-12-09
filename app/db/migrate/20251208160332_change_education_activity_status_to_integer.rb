class ChangeEducationActivityStatusToInteger < ActiveRecord::Migration[7.2]
  def change
    change_column(:education_activities, :status, :integer, using: 'status::integer')
  end
end
