# This class handles interacting with Ngrok in E2E tests, similar to how
# foreman runs `ngrok` when running the dev server with `bin/dev`.
#
# To use it in your specs:
#
#   before(:all) do
#     @ngrok = E2e::NgrokManager.new
#     @ngrok.start_tunnel(3000)       # Create tunnel to port 3000
#
#     # Do something with the Ngrok tunnel
#     puts "Ngrok is running at #{@ngrok.tunnel_url}"
#   end
#
#   after(:all) do
#     @ngrok.kill
#   end
module E2e
  class NgrokManager
    NgrokSessionLimitExceededError = Class.new(StandardError)

    def initialize
      @thread = nil
      @tunnel_url = nil
    end

    def start_tunnel(destination_port)
      retries = 0

      @thread = Thread.new do |t|
        begin
          _stdin, stdout, _stderr, wait_thr = Open3.popen3("ngrok http #{destination_port} --log stdout")
          puts "[NGROK] Started with pid #{wait_thr.pid} to local port #{destination_port}"
          stdout.each_line do |log|
            if log.include?('msg="started tunnel"')
              @tunnel_url ||= log.match(/url=([^ ]+)/)[1].strip
            elsif log.include?("limited to 1 simultaneous ngrok agent sessions")
              raise NgrokSessionLimitExceededError
            end
          end
        rescue NgrokSessionLimitExceededError
          puts "[NGROK] Session limit exceeded"
          raise if retries == 1

          puts "[NGROK] Retrying after a short delay"
          retries += 1
          sleep 2
          retry
        rescue => e
          puts "[NGROK] Fatal error: #{e}"
        ensure
          puts "[NGROK] Killing pid #{wait_thr.pid}"
          Process.kill("TERM", wait_thr.pid) if wait_thr.alive? rescue nil
        end
      end

      @thread.abort_on_exception = true
    end

    def tunnel_url
      Timeout.timeout(5) { sleep 0.1 while @tunnel_url.nil? }

      @tunnel_url
    rescue Timeout::Error => ex
      raise "[NGROK] Timed out waiting for ngrok to initialize. Make sure `ngrok http 3000 --log stdout` works locally?"
    end

    def kill
      @thread.kill if @thread
    end
  end
end
