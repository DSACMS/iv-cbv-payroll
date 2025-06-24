module E2e
  class MockingService
    SESSION_STORAGE_CALLBACKS_KEY = "e2eInvokedCallbacks" # Keep in sync with E2ECallbackRecorder
    SESSION_STORAGE_REPLAY_KEY = "e2eCallbacksToInvoke" # Keep in sync with E2ECallbackRecorder

    # Webhooks/API Requests: Use the values computed by these blocks to obscure
    # the associated values in Webhook responses and API requests (VCR).
    PLACEHOLDER_VALUES = {
      # Replaces the base64-encoded basic auth password in the "Authorization" header of API requests.
      argyle_auth_token: -> do
        Base64.strict_encode64("#{ENV["ARGYLE_API_TOKEN_SANDBOX_ID"]}:#{ENV["ARGYLE_API_TOKEN_SANDBOX_SECRET"]}")
      end,

      # Replaces the webhook signature on incoming Pinwheel webhooks.
      pinwheel_webhook_signature: ->(request_hash) do
        pinwheel = Aggregators::Sdk::PinwheelService.new("sandbox")
        timestamp = request_hash[:headers].fetch("X-Timestamp", [ "dummy-default-value" ]).first
        pinwheel.generate_signature_digest(timestamp, request_hash[:body])
      end,

      # Replaces Pinwheel's own AWS key in the (currently unused) paystub image
      # URLs to avoid Github vulnerability scan alerts.
      pinwheel_aws_credential: ->(vcr_interaction) do
        vcr_interaction.response.body.match(/X-Amz-Credential=([A-Za-z0-9\-\_\%]+)/) ? $LAST_MATCH_INFO[1] : "<PINWHEEL_AWS_KEY_ID_VALUE>"
      end
    }

    attr_reader :cassette_name

    def initialize(server_url:, record_mode: ENV["E2E_RECORD_MODE"].present?)
      @server_url = server_url
      @record_mode = record_mode

      if @record_mode
        @logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT)).tagged("E2E")
      else
        @logger = Rails.logger.tagged("E2E")
      end
    end

    def use_recording(cassette_name, &block)
      @cassette_name = cassette_name
      @webhook_replayer = E2e::NgrokRequestReplayer.new(
        logger: @logger,
        replacements: { "<PINWHEEL_WEBHOOK_SIGNATURE>" => PLACEHOLDER_VALUES[:pinwheel_webhook_signature] }
      )

      set_up_recording_mode if @record_mode

      VCR.configure do |c|
        # API Requests: Configure VCR to store placeholders instead of our actual sensitive keys.
        c.filter_sensitive_data("<ARGYLE_BASIC_AUTH>", &PLACEHOLDER_VALUES[:argyle_auth_token])
        c.filter_sensitive_data("<PINWHEEL_API_TOKEN>") { ENV["PINWHEEL_API_TOKEN_SANDBOX"] }
        c.filter_sensitive_data("<PINWHEEL_AWS_KEY_ID>", &PLACEHOLDER_VALUES[:pinwheel_aws_credential])
        c.cassette_library_dir = fixture_directory
      end

      VCR.use_cassette("vcr_http_requests", record: @record_mode ? :once : :none) do |vcr_cassette|
        freeze_time_and_remove_session_expiration(vcr_cassette.originally_recorded_at || Time.now) do
          block.call
        end
      end

      # Webhooks: Save all webhooks at the end of the run.
      if @record_mode
        File.write(
          File.join(fixture_directory, "ngrok_requests.yml"),
          YAML.dump(@webhook_replayer.list_requests)
        )
      end

      clean_up_recording_mode if @record_mode
    end

    def replay_modal_callbacks(browser, &block)
      browser.execute_script(<<~JS)
        window.sessionStorage.setItem(#{SESSION_STORAGE_CALLBACKS_KEY.inspect}, "[]");
      JS

      # Callbacks: Pass the recorded callbacks to the frontend JS by putting them in sessionStorage.
      unless @record_mode
        recorded_callbacks = YAML.load_file(File.join(fixture_directory, "aggregator_modal_callbacks.yml"))

        browser.execute_script(<<~JS)
          window.sessionStorage.setItem(
            #{SESSION_STORAGE_REPLAY_KEY.inspect},
            #{JSON.generate(recorded_callbacks).inspect}
          );
        JS
      end

      block.call
    end

    def record_modal_callbacks(browser, &block)
      return unless @record_mode

      block.call

      # Callbacks: Save the invoked callbacks by retrieving them from sessionStorage.
      invoked_callbacks_json = browser.execute_script(<<~JS)
        return window.sessionStorage.getItem(#{SESSION_STORAGE_CALLBACKS_KEY.inspect});
      JS
      raise "No callbacks recorded in sessionStorage key #{SESSION_STORAGE_CALLBACKS_KEY}" unless invoked_callbacks_json

      File.write(
        File.join(fixture_directory, "aggregator_modal_callbacks.yml"),
        YAML.dump(JSON.parse(invoked_callbacks_json))
      )
    end

    def replay_webhooks
      return if @record_mode

      recorded_requests = YAML.load_file(File.join(fixture_directory, "ngrok_requests.yml"))
      @webhook_replayer.replay_requests(recorded_requests, @server_url)
    end

    private

    def set_up_recording_mode
      assert_env("ARGYLE_API_TOKEN_SANDBOX_ID")
      assert_env("ARGYLE_API_TOKEN_SANDBOX_SECRET")
      assert_env("PINWHEEL_API_TOKEN_SANDBOX", length: 64)
      assert_env("USER")

      # TODO: Remove this when we stub out Pinwheel usage:
      # (We will have to allow access to the capybara server URL.)
      WebMock.allow_net_connect!
      # Register Ngrok with Pinwheel
      @ngrok = E2e::NgrokManager.new(logger: @logger)
      @ngrok.start_tunnel(@server_url.port)
      @logger.info "Found ngrok tunnel at #{@ngrok.tunnel_url}!"

      if Rails.application.config.supported_providers.include?(:pinwheel)
        @pinwheel_subscription_id = PinwheelWebhookManager.new.create_subscription_if_necessary(
          @ngrok.tunnel_url,
          "#{ENV["USER"]}-e2e"
        )
      end

      if Rails.application.config.supported_providers.include?(:argyle)
        @argyle_subscriptions = ArgyleWebhooksManager.new(logger: @logger).create_subscriptions_if_necessary(
          @ngrok.tunnel_url,
          "#{ENV["USER"]}-e2e"
        )
      end
    end

    def clean_up_recording_mode
      if @pinwheel_subscription_id
        @logger.tagged("PINWHEEL").info "Deleting webhook subscription id: #{@pinwheel_subscription_id}"
        Aggregators::Sdk::PinwheelService.new("sandbox").delete_webhook_subscription(@pinwheel_subscription_id)
      end

      if @argyle_subscriptions
        @argyle_subscriptions.each do |id|
          @logger.tagged("ARGYLE").info "Deleting webhook subscription id: #{id}"
          Aggregators::Sdk::ArgyleService.new("sandbox").delete_webhook_subscription(id)
        end
      end

      @ngrok.kill if @ngrok
    end

    # Freeze time so that the time-based API queries (e.g. requesting 90
    # days of aggregator data) will always use the same dates.
    #
    # This also requires removing session expiration, since Rails sets the
    # cookies to expire 30 minutes after the request.
    def freeze_time_and_remove_session_expiration(time, &block)
      old_session_store = Rails.application.config.session_store
      Rails.application.config.session_store :cookie_store, key: "_iv_cbv_payroll_session"

      Timecop.freeze(time) do
        block.call
      end
    ensure
      Rails.application.config.session_store(old_session_store)
    end

    def fixture_directory
      Rails.root.join("spec", "fixtures", "e2e", @cassette_name).tap do |directory|
        FileUtils.mkdir_p(directory)
      end
    end

    def assert_env(name, length: nil)
      unless ENV[name].present? && (length.nil? || ENV[name].length == length)
        raise "You need to set #{name} in order to record E2E tests. Consider adding it to .env.test.local."
      end
    end
  end
end
