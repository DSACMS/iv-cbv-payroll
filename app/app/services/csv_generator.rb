class CsvGenerator
  def self.create_csv(data)
    csv_string = CSV.generate do |csv|
      csv << data.keys
      csv << data.values
    end
    StringIO.new(csv_string)
  end
end
