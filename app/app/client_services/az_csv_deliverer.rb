class AzCsvDeliverer
  attr_reader :current_agency, :start_date, :end_date
  def initialize(current_agency, start_date, end_date)
    @current_agency = current_agency
    @start_date = start_date
    @end_date = end_date
  end

  def process
  end
end
