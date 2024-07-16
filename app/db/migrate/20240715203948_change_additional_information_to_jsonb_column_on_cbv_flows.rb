class ChangeAdditionalInformationToJsonbColumnOnCbvFlows < ActiveRecord::Migration[7.1]
  def change
    # empty existing non-null and non-empty values
    execute <<-SQL
      UPDATE cbv_flows
      SET additional_information = '{}'
      WHERE additional_information IS NOT NULL
        AND additional_information != ''
    SQL

    # change column type to JSONB and add a default value
    change_column :cbv_flows, :additional_information, :jsonb,
                  default: {},
                  using: "COALESCE(additional_information::jsonb, '{}'::jsonb)"
  end
end
