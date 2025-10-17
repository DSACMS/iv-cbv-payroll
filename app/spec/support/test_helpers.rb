require 'pdf-reader'

module TestHelpers
  def stub_environment_variable(variable, value, &block)
    previous_value = ENV[variable]
    ENV[variable] = value
    block.call
    ENV[variable] = previous_value
  end

  def stub_payments(account_id = SecureRandom.uuid)
    5.times.map do |i|
      json = {
        "account_id" => account_id,
        "employer" => "Employer #{i + 1}",
        "net_pay_amount" => (100 * (i + 1)),
        "gross_pay_amount" => (120 * (i + 1)),
        "rate" => (10 + i),
        "pay_date" => "2020-01-14",
        "pay_period_start" => "2020-01-01",
        "pay_period_end" => "2020-01-14",
        "gross_pay_ytd" => 1_000,
        "deductions" => [],
        "earnings" => []
      }

      Aggregators::ResponseObjects::Paystub.from_pinwheel(json)
    end
  end

  def stub_employments(account_id = SecureRandom.uuid)
    5.times.map do |i|
      fields = {
        "account_id" => account_id,
        "status" => "employed",
        "start_date" => "2010-01-01",
        "termination_date" => nil,
        "employer_name" => "Acme Corporation",
        "employer_address" => {
          "raw" => "20429 Pinwheel Drive, New York City, NY 99999"
        },
        "employer_phone_number" => {
          "value" => "+16126597057"
        },
        "title" => nil
      }

      Aggregators::ResponseObjects::Employment.from_pinwheel(fields)
    end
  end

  def stub_incomes(account_id = SecureRandom.uuid)
    5.times.map do |i|
      fields = {
        "account_id" => account_id,
        "id" => "c70bde4d-e1c2-427a-adc1-c17f61eff210",
        "created_at" => "2024-08-19T19:27:03.220201+00:00",
        "updated_at" => "2024-08-19T19:27:03.220201+00:00",
        "compensation_amount" => 1000,
        "compensation_unit" => "hourly",
        "currency" => "USD",
        "pay_frequency" => "bi-weekly"
      }

      Aggregators::ResponseObjects::Income.from_pinwheel(fields)
    end
  end

  def stub_identities(account_id = SecureRandom.uuid)
    5.times.map do |i|
      fields = {
        "id" => "9583558c-f54c-455d-9519-554416106a0a",
        "created_at" => "2024-08-23T19:26:34.541298+00:00",
        "updated_at" => "2024-08-23T19:26:34.541298+00:00",
        "account_id" => account_id,
        "full_name" => "Ash Userton",
        "emails" => [
          "user_good@example.com"
        ],
        "date_of_birth" => "1993-08-28",
        "last_four_ssn" => "1234",
        "address" => {
          "raw" => "20429 Pinwheel Drive, New York City, NY 99999",
          "line1" => "20429 Pinwheel Drive",
          "line2" => nil,
          "city" => "New York City",
          "state" => "NY",
          "postal_code" => "99999",
          "country" => "US"
        },
        "phone_numbers" => [
          {
            "value" => "+12345556789",
            "type" => nil
          }
        ]
      }

      Aggregators::ResponseObjects::Identity.from_pinwheel(fields)
    end
  end

  def stub_client_agency_config_value(client_agency_id, key, value)
    client_agency_config = Rails.application.config.client_agencies[client_agency_id]
    allow(client_agency_config).to receive(key.to_sym).and_return(value)
  end

  def override_supported_providers(new_value)
    old_value = Rails.application.config.supported_providers
    Rails.application.config.supported_providers = new_value
    yield
  ensure
    Rails.application.config.supported_providers = old_value
  end

  def extract_pdf_text(response)
    pdf = PDF::Reader.new(StringIO.new(response.body))
    pdf_text = ""
    pdf.pages.each do |page|
      pdf_text += page.text.gsub(/\s+/, ' ')
    end
    pdf_text
  end
end
