# End-to-End (E2E) Tests

## Overview
How to run E2E tests:
* **Run in *replay* mode:** `E2E_RUN_TESTS=1 bin/rspec spec/e2e`
  * Note: Soon, we will enable these to run by default, so the environment variable prefix won't be necessary.
* **Run in *record* mode:** `E2E_RECORD_MODE=1 bin/rspec [spec/e2e/your_spec.rb:123]`
  * You will need environment variables set for Argyle and Pinwheel. Add these to `.env.local` or `.env.test.local`.

Example boilerplate for a new test:

```ruby
RSpec.describe "Test name here", type: :feature, js: true do
  around do |ex|
    @e2e = E2e::MockingService.new(server_url: URI(page.server_url))
    @e2e.use_recording("your_test_name_here", &ex)
  end

  it "proceeds through the CBV flow" do
    # ... Initial page navigation through the flow ...

    # Uncomment for pinwheel only:
    # update_cbv_flow_with_deterministic_end_user_id_for_pinwheel(@e2e.cassette_name)

    @e2e.replay_modal_callbacks(page.driver.browser) do
      click_button "Uber"               # The click event that opens the modal must be within this block.
      # In replay mode, the callbacks will be sent to the ModalAdapter instead of the aggregator modal opening.
    end

    @e2e.record_modal_callbacks(page.driver.browser) do
      # In record mode, this is where to interact with the aggregator modal.
      # In replay mode, this will be skipped.
    end

    @e2e.replay_webhooks # Only invoked in "replay" mode.

    # ...
  end
end
```

## "Record mode" vs "Replay mode"
Tests run by default in "replay mode", which replays E2E recordings so we don't make requests to third-party systems (like Argyle/Pinwheel). When adding or changing a test, we first need to use "record mode" to save the aggregator data recordings, and commit the `spec/support/fixtures/e2e/` folder for that recording.

The recording has three different types of mocks for our three main external integrations. Each has different record/replay semantics:
1. **Modal Callbacks:** To record/replay the aggregator modals themselves, we have `E2eCallbackRecorder.ts` to record/replay the callbacks.
  * **Record mode:** The `E2eCallbackRecorder` intercepts all callbacks between the ModalAdapter and the actual modal SDK. They are stored in `aggregator_modal_callbacks.yml`.
  * **Replay mode:** No aggregator modal is instantiated. Instead, `E2eCallbackRecorder` invokes the ModalAdapter callbacks in the original order (and with the same arguments) as in the recording.
2. **Aggregator API Requests:** We also fetch data from the Aggregator APIs when rendering the report pages. We record these using the `vcr` gem.
  * **Record mode:** VCR will record all HTTP requests and save them into `vcr_http_requests.yml`
  * **Replay mode:** VCR is configured to use the given API responses from that file whenever a matching HTTP request is seen.
3. **Aggregator Webhooks:** We also receive webhooks from the aggregators during the sync process.
  * **Record mode:** Using ngrok, we record all incoming webhooks. They are store in `ngrok_requests.yml`
  * **Replay mode:** We re-send all saved webhooks in order.

To record the data for these methods, you must include the following method calls in your test:
* **`@e2e.replay_modal_callbacks`**
* **`@e2e.record_modal_callbacks`**
* **`@e2e.replay_webhooks`**

## Developing on E2E classes
The E2E test framework lives in `spec/support/e2e`. If you need to update a file in there, here are some tips:
* To reproduce the CI environment, unset your PINWHEEL_API_TOKEN_SANDBOX, ARGYLE_API_TOKEN_SANDBOX_ID, and ARGYLE_API_TOKEN_SANDBOX_SECRET. Unset these, then run your test in "replay mode" to see how it will fare in CI.
* The tests need to freeze time. To test this locally, try changing your computer's date into the future.
* The E2e::MockService and a couple other classes log their status to the test log. I recommend having `tail -f log/test.log` running in a terminal tab when recording examples.

When editing the `E2eCallbackRecorder.js` file:
* Make sure you're running the esbuild command in another terminal (or `bin/dev`).

## Currently unsupported E2E test conditions
* Multiple openings of the aggregator modals (either multiple Pinwheel, or Pinwheel then Argyle)
* Anything regarding session expiration (as we currently remove session expiration during E2E testing)
