#!/usr/bin/env ruby
# frozen_string_literal: true

# Conservative Ruby dependency vulnerability fixer.
#
# Usage: bundle exec ruby fix-ruby-dependencies.rb   (run from the app/ dir)
#
# Runs bundler-audit against the current bundle, then for each gem an advisory
# flags runs `bundle update --conservative <gem>` to pull in the smallest
# release that clears the advisory while respecting Gemfile constraints.
# Emits changes_made to GITHUB_OUTPUT and a markdown summary to
# PATCH_SUMMARY_FILE, mirroring patch-dockerfile.rb's output contract so the
# same PR-opening plumbing consumes it.
#
# A gem whose fix needs a version outside the Gemfile constraint stays
# unchanged (conservative update is a no-op); it is reported in the summary but
# not auto-bumped, since that would require editing the Gemfile by hand.

require 'json'

LOCKFILE = 'Gemfile.lock'

def sh(cmd)
  puts "+ #{cmd}"
  system(cmd)
end

# Pulls gem name / version / advisory details out of bundler-audit scan
# results. Duck-typed so tests can pass plain stubs: an unpatched-gem result
# responds to both #gem and #advisory.
def advisories_from_results(results)
  results.filter_map do |result|
    next unless result.respond_to?(:gem) && result.respond_to?(:advisory)

    spec = result.gem
    advisory = result.advisory
    patched = advisory.respond_to?(:patched_versions) ? Array(advisory.patched_versions) : []

    {
      gem: spec.name,
      version: spec.version.to_s,
      advisory: (advisory.id if advisory.respond_to?(:id)),
      title: (advisory.title if advisory.respond_to?(:title)),
      patched_versions: patched.map(&:to_s)
    }
  end
end

def scan_results(root)
  require 'bundler/audit/database'
  require 'bundler/audit/scanner'

  Bundler::Audit::Database.update!(quiet: true)
  Bundler::Audit::Scanner.new(root).scan.to_a
rescue LoadError
  warn 'bundler-audit not available; skipping Ruby dependency scan.'
  []
end

def gems_to_update(advisories)
  advisories.map { |a| a[:gem] }.uniq.sort
end

def update_gems(gems, runner:)
  gems.each do |gem_name|
    cmd = "BUNDLE_FROZEN=false bundle update --conservative #{gem_name}"
    warn "#{cmd} failed" unless runner.call(cmd)
  end
end

def lockfile_changed?(runner:)
  # git diff --quiet exits 0 with no diff, 1 when the lockfile changed.
  !runner.call("git diff --quiet -- #{LOCKFILE}")
end

def set_github_output(key, value)
  output_file = ENV['GITHUB_OUTPUT']
  return unless output_file

  File.open(output_file, 'a') { |f| f.puts("#{key}=#{value}") }
end

def write_summary(advisories)
  summary_file = ENV['PATCH_SUMMARY_FILE']
  return unless summary_file

  out = +"### Vulnerable gems updated\n\n"
  advisories.sort_by { |a| a[:gem] }.each do |a|
    patched = a[:patched_versions].empty? ? 'n/a' : a[:patched_versions].join(', ')
    out << "- `#{a[:gem]}` (was #{a[:version]}) — #{a[:advisory]}: patched in #{patched}\n"
  end
  out << "\n"

  File.write(summary_file, out)
end

def main(results:, runner: method(:sh))
  advisories = advisories_from_results(results)

  if advisories.empty?
    puts 'No vulnerable gems found.'
    set_github_output('changes_made', 'false')
    return
  end

  gems = gems_to_update(advisories)
  puts "Vulnerable gems (#{gems.size}): #{gems.join(', ')}"
  update_gems(gems, runner: runner)

  if lockfile_changed?(runner: runner)
    write_summary(advisories)
    set_github_output('changes_made', 'true')
    puts "#{LOCKFILE} updated."
  else
    puts "#{LOCKFILE} unchanged; fixes may require a manual major-version bump."
    set_github_output('changes_made', 'false')
  end
end

main(results: scan_results('.')) if $PROGRAM_NAME == __FILE__
