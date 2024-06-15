module CbvFlowsHelper
  def format_date(timestamp_string)
    begin
      Time.parse(timestamp_string).strftime("%B %d, %Y")
    rescue => e
      "Invalid timestamp"
      timestamp_string
    end
  end
end
