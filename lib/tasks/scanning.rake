desc "Run brakeman with potential non-0 return code"
task :brakeman do
  # -z flag makes it return non-0 if there are any warnings
  # -q quiets output
  unless system("brakeman -z -q") # system is true if return is 0, false otherwise
    abort("Brakeman detected one or more code problems, please run it manually and inspect the output.")
  end
end

namespace :bundler do
  require "bundler/audit/cli"

  desc "Updates the ruby-advisory-db and runs audit"
  task :audit do
    %w[update check].each do |command|
      Bundler::Audit::CLI.start [command]
    end
  end
rescue LoadError
  # no-op, probably in a production environment
end

namespace :yarn do
  desc "Run yarn audit"
  task :audit do
    require "open3"
    stdout, stderr, status = Open3.capture3("yarn audit --json")
    unless status.success?
      puts stderr
      parsed = JSON.parse("[#{stdout.lines.join(",")}]")
      puts JSON.pretty_generate(parsed)
      if /503 Service Unavailable/.match?(stderr)
        puts "Ignoring unavailable server"
      elsif all_issues_ignored?(parsed)
        puts "Ignoring known and accepted yarn audit results"
      else
        puts "Failed with exit code #{status.exitstatus}"
        exit status.exitstatus
      end
    end
  end
end

def all_issues_ignored?(issues)
  present_advisories_with_frequencies = Hash.new { |hash, key| hash[key] = 0 }

  # Only look at audit advisories, and not audit summaries
  issues.select { |issue_json| issue_json["type"] == "auditAdvisory" }.each do |issue_json|
    present_advisories_with_frequencies[issue_json["data"]["advisory"]["id"]] += 1
  end

  # Advisory ID to be ignored with number of times it appears in project dependencies
  # And, a comment as to why we're ignoring
  ignored_advisories_with_frequencies = {
    # 1005154 => 2, # high - inefficient regex in dev server and at build time
  }

  pp "Present advisories: #{present_advisories_with_frequencies}"
  pp "Ignored advisories: #{ignored_advisories_with_frequencies}"
  present_advisories_with_frequencies == ignored_advisories_with_frequencies
end

task default: ["standard", "brakeman", "bundler:audit", "yarn:audit"]
