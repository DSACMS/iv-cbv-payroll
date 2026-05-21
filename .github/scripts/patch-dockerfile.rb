#!/usr/bin/env ruby
# frozen_string_literal: true

# Add-only Dockerfile OS package patcher.
#
# Usage: ruby patch-dockerfile.rb <trivy-results.json> <grype-results.json> <Dockerfile>
#
# Reads Trivy and Grype JSON output and adds any packages either scanner flags
# as fixable to the auto-managed RUN block in the Dockerfile's BASE stage. The
# union is taken because Trivy and Grype use different vulnerability databases
# and routinely disagree on which CVEs apply to a given package version.
# Both parsers restrict results to OS packages — Trivy via Class == "os-pkgs",
# Grype via artifact.type in {deb, apk, rpm} — so only apt-installable names
# reach the RUN block.
# Removal is intentionally manual — scanners run with --ignore-unfixed / only-fixed
# cannot distinguish "fix shipped in the new base image" from "fix already
# applied by this auto-fix block", so auto-removing risks reintroducing the CVE
# on the next build. Clear the block manually when bumping the base Ruby image.
#
# Only manages blocks marked with the AUTOFIX_MARKER comment.
# Never touches the manually-maintained "Upgrade packages in base image" block.



require 'json'
require 'set'

AUTOFIX_MARKER    = '# Auto-fix: OS package vulnerabilities detected by Trivy and Grype'
INSERTION_ANCHOR  = '# Rails app lives here'
OS_PACKAGE_TYPES  = Set['deb', 'apk', 'rpm'].freeze

def parse_trivy(trivy_path)
  data = JSON.parse(File.read(trivy_path))
  needed = Set.new

  (data['Results'] || []).each do |result|
    next unless result['Class'] == 'os-pkgs'

    (result['Vulnerabilities'] || []).each do |vuln|
      next if vuln['FixedVersion'].to_s.empty?

      needed.add(vuln['PkgName'])
    end
  end

  needed
end

def parse_grype(grype_path)
  data = JSON.parse(File.read(grype_path))
  needed = Set.new

  (data['matches'] || []).each do |match|
    next unless OS_PACKAGE_TYPES.include?(match.dig('artifact', 'type'))

    fix = match.dig('vulnerability', 'fix') || {}
    next unless fix['state'] == 'fixed'
    next if (fix['versions'] || []).empty?

    name = match.dig('artifact', 'name')
    needed.add(name) if name
  end

  needed
end

def parse_autofix_block(lines)
  start_idx = -1
  end_idx   = -1
  packages  = Set.new

  lines.each_with_index do |line, i|
    start_idx = i if line.include?(AUTOFIX_MARKER)

    next unless start_idx != -1 && end_idx == -1

    # Package lines look like: '      pkgname \' or '      pkgname=version \'
    if (m = line.match(/^\s{6}([a-z0-9][a-z0-9.+-]*)(?:=[^\s\\]+)?\s*\\?\s*$/))
      packages.add(m[1])
    end

    # The block ends at the apt cleanup line
    if line.include?('rm -rf /var/lib/apt/lists')
      end_idx = i
      break
    end
  end

  [start_idx, end_idx, packages]
end

def build_autofix_block(packages)
  pkg_lines = packages.sort.map { |pkg| "      #{pkg} \\\n" }

  [
    "#{AUTOFIX_MARKER} (managed automatically)\n",
    "# hadolint ignore=DL3008\n",
    "RUN apt-get update -qq && \\\n",
    "    apt-get install -y --no-install-recommends \\\n",
    *pkg_lines,
    "    && \\\n",
    "    rm -rf /var/lib/apt/lists /var/cache/apt/archives\n"
  ]
end

def find_insertion_index(lines)
  lines.each_with_index { |line, i| return i if line.include?(INSERTION_ANCHOR) }
  -1
end

def set_github_output(key, value)
  output_file = ENV['GITHUB_OUTPUT']
  return unless output_file

  File.open(output_file, 'a') { |f| f.puts("#{key}=#{value}") }
end

def write_summary(added)
  summary_file = ENV['PATCH_SUMMARY_FILE']
  return unless summary_file

  out = +"### Packages added\n\n"
  added.sort.each { |pkg| out << "- `#{pkg}`\n" }
  out << "\n"

  File.write(summary_file, out)
end

def main(trivy_path, grype_path, dockerfile_path)
  from_trivy = parse_trivy(trivy_path)
  from_grype = parse_grype(grype_path)
  needed = from_trivy | from_grype

  puts "Trivy flagged: #{from_trivy.sort}"
  puts "Grype flagged: #{from_grype.sort}"
  puts "Union (#{needed.size} package(s) with fixes available): #{needed.sort}"

  lines = File.readlines(dockerfile_path)

  block_start, block_end, currently_patched = parse_autofix_block(lines)
  puts "Currently in auto-fix block: #{currently_patched.sort}"

  to_add = needed - currently_patched
  stale  = currently_patched - needed
  if stale.any?
    puts "Already-patched packages no longer flagged (kept; manual cleanup at base image bump): #{stale.sort}"
  end

  if to_add.empty?
    puts 'No new packages to add.'
    set_github_output('changes_made', 'false')
    return
  end

  puts "Adding: #{to_add.sort}"

  new_packages = currently_patched | to_add

  if block_start != -1
    lines[block_start..block_end] = build_autofix_block(new_packages)
  else
    insert_at = find_insertion_index(lines)
    if insert_at == -1
      warn "ERROR: Could not find insertion anchor '#{INSERTION_ANCHOR}' in Dockerfile."
      exit 1
    end
    # Insert block + blank separator before the anchor
    lines.insert(insert_at, *build_autofix_block(new_packages), "\n")
  end

  File.write(dockerfile_path, lines.join)
  puts "Dockerfile updated: #{dockerfile_path}"

  write_summary(to_add)
  set_github_output('changes_made', 'true')
end

if $PROGRAM_NAME == __FILE__
  if ARGV.size != 3
    warn "Usage: #{$PROGRAM_NAME} <trivy-results.json> <grype-results.json> <Dockerfile>"
    exit 1
  end

  main(ARGV[0], ARGV[1], ARGV[2])
end
