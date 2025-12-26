namespace :benchmark do
  # Attempt to create a representative sample of jobs based on frequency for
  # real users:
  NUM_ANALYTICS_JOBS = 4000   # Roughly 200x the average of 20.4 events/user.
  NUM_TRANSMITTER_JOBS = 20   # Roughly 200x the average of 0.09 reports/user.

  # Use a different queue name for better traceability
  BENCHMARK_QUEUE = "benchmark"

  # How to run this benchmark:
  # 1. Update the environment variables to minimize blast radius:
  #     * SLACK_TEST_EMAIL=success@simulator.amazonses.com
  # 2. Restart the worker containers so they pick up the new environment
  #    variable.
  # 3. Create a CBV Flow in Sandbox that you will use to transmit:
  #     * https://sandbox-verify-demo.navapbc.cloud
  # 4. Call this rake task with the ID of the CBV Flow you just created:
  #     > bin/rails 'benchmark:workers[123]'
  # 5. Reset the SLACK_TEST_EMAIL value and restart the containers back to the
  #    proper configuration.
  desc "Benchmark worker performance by enqueuing a bunch of jobs"
  task :workers, [ :cbv_flow_id ] => [ :environment ] do |_, args|
    cbv_flow_id = args[:cbv_flow_id]
    unless cbv_flow_id
      puts "You must pass a CBV Flow ID to transmit"
      next
    end

    puts "Instantiating #{NUM_ANALYTICS_JOBS} analytics jobs and #{NUM_TRANSMITTER_JOBS} transmitter jobs..."
    analytics_jobs = NUM_ANALYTICS_JOBS.times.map do |i|
      EventTrackingJob
        .new("BenchmarkEvent", {}, { job_index: i })
        .set(queue: BENCHMARK_QUEUE)
    end
    transmitter_jobs = NUM_TRANSMITTER_JOBS.times.map do |i|
      CaseWorkerTransmitterJob
        .new(cbv_flow_id)
        .set(queue: BENCHMARK_QUEUE)
    end

    while SolidQueue::ReadyExecution.where(queue_name: BENCHMARK_QUEUE).any?
      puts "Waiting for '#{BENCHMARK_QUEUE}' queue to empty..."
      sleep 1
    end

    puts "Enqueuing jobs..."
    ActiveJob.perform_all_later(analytics_jobs, transmitter_jobs)

    # Benchmark!
    time_started = Time.now
    puts "Waiting for '#{BENCHMARK_QUEUE}' queue to become fully empty again..."
    while SolidQueue::ReadyExecution.where(queue_name: BENCHMARK_QUEUE).any?
      sleep 0.1
    end
    time_ended = Time.now

    total_jobs = NUM_ANALYTICS_JOBS + NUM_TRANSMITTER_JOBS
    total_duration = time_ended - time_started
    puts "Processed #{total_jobs} jobs in #{total_duration} seconds!"
    puts "  = #{(total_jobs / total_duration).round(2)} jobs/second"
    puts "  = #{(total_jobs / total_duration * 60).round(2)} jobs/minute"
  end
end
