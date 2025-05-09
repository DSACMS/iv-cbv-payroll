class CsvGenerator
  def generate_csv(cbv_flow, pdf_output, filename)
    raise "not implemented"
  end

  def self.create_csv(data)
    csv_string = CSV.generate do |csv|
      csv << data.keys
      csv << data.values
    end
    StringIO.new(csv_string)
  end
end
