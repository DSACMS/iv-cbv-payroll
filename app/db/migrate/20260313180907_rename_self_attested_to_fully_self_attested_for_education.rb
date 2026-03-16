# frozen_string_literal: true

class RenameSelfAttestedToFullySelfAttestedForEducation < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE education_activities
      SET data_source = 'fully_self_attested'
      WHERE data_source = 'self_attested'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE education_activities
      SET data_source = 'self_attested'
      WHERE data_source = 'fully_self_attested'
    SQL
  end
end
