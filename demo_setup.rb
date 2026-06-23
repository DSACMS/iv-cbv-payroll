# demo_setup.rb — ensure the NATIVE system libraries the PDF/image demos need are
# present, so anyone who checks out this branch can just run `ruby <demo>.rb`.
#
# Why this exists: ruby-vips loads libvips at runtime, and the rmagick gem compiles
# a native extension against ImageMagick at install time. Neither works without the
# underlying system library. This installs them via the platform package manager
# (Homebrew on macOS, apt on Debian/Ubuntu) BEFORE the gems are required.
#
# Usage (must run before `require "bundler/inline"`):
#   require_relative "demo_setup"
#   DemoSetup.ensure({ check: "vips", brew: "vips", apt: "libvips-tools libvips-dev" })

module DemoSetup
  module_function

  # Each spec: { check: "<binary on PATH>", brew: "<formula>", apt: "<pkg(s)>" }
  def ensure(*specs)
    specs.each do |spec|
      next if present?(spec[:check])
      puts "[demo-setup] missing '#{spec[:check]}' — installing..."
      install(spec)
      next if present?(spec[:check])
      abort <<~MSG
        [demo-setup] Could not install '#{spec[:check]}' automatically.
        Install it manually, then re-run:
          macOS:         brew install #{spec[:brew]}
          Debian/Ubuntu: sudo apt-get install -y #{spec[:apt]}
      MSG
    end
  end

  def present?(bin)
    system("command -v #{bin} > /dev/null 2>&1")
  end

  def install(spec)
    if mac? && present?("brew")
      run("brew install #{spec[:brew]}")
    elsif present?("apt-get")
      run("sudo apt-get update && sudo apt-get install -y #{spec[:apt]}")
    else
      abort "[demo-setup] No supported package manager found. Install '#{spec[:check]}' manually."
    end
  end

  def run(cmd)
    puts "[demo-setup] #{cmd}"
    system(cmd) || abort("[demo-setup] command failed: #{cmd}")
  end

  def mac?
    RUBY_PLATFORM.include?("darwin")
  end
end
