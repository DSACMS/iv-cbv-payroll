# frozen_string_literal: true

module Aggregators::Sdk
  class MockArgyleService
    attr_reader :webhook_secret

    # Use Bob's fixtures as the default mock data
    MOCK_FIXTURE_USER = "bob"

    def initialize(environment, api_key_id = nil, api_key_secret = nil, webhook_secret = nil, fixture_user: nil)
      @environment = ArgyleService::ENVIRONMENTS.fetch(environment.to_sym)
      @webhook_secret = webhook_secret || @environment[:webhook_secret]
      @fixture_user = fixture_user || MOCK_FIXTURE_USER
      @fixture_path = Rails.root.join("spec", "support", "fixtures", "argyle", @fixture_user)
    end

    def fetch_identities_api(account: nil, user: nil, employment: nil, limit: 10)
      load_fixture("request_identity.json")
    end

    def fetch_account_api(account: nil)
      load_fixture("request_account.json")
    end

    def fetch_paystubs_api(account: nil, user: nil, employment: nil, from_start_date: nil, to_start_date: nil, limit: 200)
      load_fixture("request_paystubs.json")
    end

    def fetch_gigs_api(account: nil, user: nil, from_start_datetime: nil, to_start_datetime: nil, limit: 200)
      load_fixture("request_gigs.json")
    end

    def employer_search(query, status = %w[healthy issues])
      load_fixture("request_employer_search.json")
    end

    def fetch_accounts_api(user: nil, item: nil, ongoing_refresh_status: nil, limit: 10)
      load_fixture("request_accounts.json")
    end

    def create_user(cbv_flow_end_user_id = nil)
      load_fixture("../response_create_user.json")
    end

    def create_user_token(user_id)
      load_fixture("../response_create_user_token.json")
    end

    # Webhook methods - return empty/success responses
    def get_webhook_subscriptions
      { "results" => [], "next" => nil }
    end

    def create_webhook_subscription(events, url, name, config = {})
      load_fixture("../response_create_webhook_subscription.json")
    end

    def delete_webhook_subscription(id)
      nil # 204 No Content
    end

    def delete_account_api(account:)
      nil # 204 No Content
    end

    private

    def load_fixture(filename)
      file_path = @fixture_path.join(filename)
      JSON.parse(File.read(file_path))
    rescue Errno::ENOENT => e
      Rails.logger.warn "MockArgyleService: Fixture not found: #{file_path}"
      { "results" => [], "next" => nil }
    end
  end
end
