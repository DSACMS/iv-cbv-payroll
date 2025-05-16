class CsvGenerator
  def generate_csv(cbv_flow, pdf_output, filename)
    raise "not implemented"
  end

  def self.create_csv_multiple_datapoints(rows)
    csv_string = CSV.generate do |csv|
      first_row = rows.first
      csv << first_row.keys
      rows.each do |row|
        csv << row.values
      end
    end
    StringIO.new(csv_string)
  end
end
