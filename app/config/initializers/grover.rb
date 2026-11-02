Grover.configure do |config|
  config.options = {
    format: "A4",
    tagged: true,
    outline: true,
    print_background: true,
    emulate_media: "screen",
    viewport: { width: 1280, height: 1024 },
    wait_until: "networkidle0",
    timeout: 30_000,
    executable_path: ENV["PUPPETEER_EXECUTABLE_PATH"],
    launch_args: [ "--disable-dev-shm-usage" ]
  }.compact
end
