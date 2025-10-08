namespace :load_test do
  # Clean up incomplete test sessions for load testing
  #
  # Usage:
  #   # Interactive mode (prompts for confirmation):
  #   bin/rails load_test:cleanup_cookies[sandbox]
  #
  #   # Auto-confirm mode (no prompt):
  #   bin/rails load_test:cleanup_cookies[sandbox,true]
  #
  # Arguments:
  #   client_agency_id - The client agency to clean up (default: "sandbox")
  #   auto_confirm     - Skip confirmation prompt if "true" (default: false)
  desc "Clean up test sessions created by seed_sessions"
  task :cleanup_cookies, [ :client_agency_id, :auto_confirm ] => :environment do |t, args|
    client_agency_id = args[:client_agency_id] || "sandbox"
    auto_confirm = args[:auto_confirm] == "true"

    # Find flows without confirmation codes (incomplete) from the test agency
    test_flows = CbvFlow.incomplete.where(client_agency_id: client_agency_id)

    puts "Found #{test_flows.count} incomplete test sessions for #{client_agency_id}"

    if auto_confirm
      response = "y"
      puts "Auto-confirming deletion..."
    else
      print "Delete these sessions? (y/n): "
      response = STDIN.gets.chomp.downcase
    end

    if response == "y"
      count = test_flows.count

      # Delete in proper order to avoid foreign key constraint violations
      test_flows.each do |flow|
        flow.payroll_accounts.each do |account|
          # Use destroy_all to properly delete webhook events
          account.webhook_events.destroy_all
        end
        flow.destroy
      end

      puts "✓ Deleted #{count} test sessions"
    else
      puts "Cancelled"
    end
  end
end
