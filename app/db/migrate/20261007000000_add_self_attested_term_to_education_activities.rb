class AddSelfAttestedTermToEducationActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :education_activities, :self_attested_enrollment_status, :string
    add_column :education_activities, :self_attested_term_start, :date
    add_column :education_activities, :self_attested_term_end, :date
    reversible do |direction|
      direction.up { change_column :education_activities, :credit_hours, :decimal, precision: 10, scale: 2 }
      direction.down { change_column :education_activities, :credit_hours, :integer }
    end
  end
end
