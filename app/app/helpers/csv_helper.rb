
module CsvHelper
  def create_csv(path, data = {})
    CSV.open(path, "w") do |csv|
      csv << data.keys
      csv << data.values
    end
    path
  end
end
