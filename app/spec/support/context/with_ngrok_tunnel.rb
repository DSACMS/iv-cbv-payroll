require "open3"

# This shared context handles the lifecycle of an ngrok subprocess.
#
# To use it in your specs:
#
#   include_context "with_ngrok_tunnel"
#
# and then in your before/after blocks:
#
#   before(:all) do
#     @ngrok.start_tunnel(3000)       # Create tunnel to port 3000
#
#     # Do something with the Ngrok tunnel
#     puts "Ngrok is running at #{@ngrok.tunnel_url}"
#   end
RSpec.shared_context "with_ngrok_tunnel" do
  class NgrokManager
    def initialize
      @thread = nil
      @tunnel_url = nil
    end

    def start_tunnel(destination_port)
      @thread = Thread.new do |t|
        begin
          _stdin, stdout, _stderr, wait_thr = Open3.popen3("ngrok http #{destination_port} --log stdout")
          puts "[NGROK] Started with pid #{wait_thr.pid} to local port #{destination_port}"
          stdout.each_line do |log|
            if log.include?('msg="started tunnel"')
              @tunnel_url ||= log.match(/url=([^ ]+)/)[1].strip
            end
          end
        rescue => e
          puts "[NGROK] Fatal error: #{e}"
        ensure
          puts "[NGROK] Killing pid #{wait_thr.pid}"
          Process.kill("TERM", wait_thr.pid) if wait_thr.alive?
        end
      end
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

  before(:all) do
    @ngrok = NgrokManager.new
  end

  after(:all) do
    @ngrok.kill if @ngrok
  end
end
