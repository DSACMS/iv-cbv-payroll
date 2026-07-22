#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize,Metrics/ClassLength,Metrics/MethodLength,Style/Documentation

require 'minitest/autorun'
require 'tempfile'

require_relative 'fix-ruby-dependencies'

class FixRubyDependenciesTest < Minitest::Test
  # Minimal stand-ins for bundler-audit's UnpatchedGem result graph.
  Spec = Struct.new(:name, :version)
  Advisory = Struct.new(:id, :title, :patched_versions)
  UnpatchedGem = Struct.new(:gem, :advisory)
  InsecureSource = Struct.new(:source) # no #gem / #advisory — must be ignored

  def unpatched(name:, version:, id:, patched:)
    UnpatchedGem.new(Spec.new(name, version), Advisory.new(id, "#{name} advisory", patched))
  end

  # A command runner that records invocations and returns a caller-provided
  # boolean per matched command prefix (mirrors system's true/false).
  class FakeRunner
    attr_reader :commands

    def initialize(diff_dirty: false, update_ok: true)
      @commands = []
      @diff_dirty = diff_dirty
      @update_ok = update_ok
    end

    def to_proc
      proc do |cmd|
        @commands << cmd
        if cmd.start_with?('git diff --quiet')
          @diff_dirty ? false : true # `git diff --quiet` exits 1 (false) when dirty
        else
          @update_ok
        end
      end
    end
  end

  # --- advisories_from_results ---

  def test_extracts_gem_advisory_fields
    results = [unpatched(name: 'nokogiri', version: '1.13.0', id: 'CVE-2022-1', patched: ['>= 1.13.6'])]

    advisories = advisories_from_results(results)

    assert_equal 1, advisories.size
    assert_equal 'nokogiri', advisories.first[:gem]
    assert_equal '1.13.0', advisories.first[:version]
    assert_equal 'CVE-2022-1', advisories.first[:advisory]
    assert_equal ['>= 1.13.6'], advisories.first[:patched_versions]
  end

  def test_ignores_results_without_gem_and_advisory
    results = [
      unpatched(name: 'rack', version: '2.0.0', id: 'CVE-x', patched: ['>= 2.0.1']),
      InsecureSource.new('git://example.com')
    ]

    advisories = advisories_from_results(results)

    assert_equal ['rack'], advisories.map { |a| a[:gem] }
  end

  def test_gems_to_update_dedups_and_sorts
    advisories = [
      { gem: 'rack' }, { gem: 'nokogiri' }, { gem: 'rack' }
    ]

    assert_equal %w[nokogiri rack], gems_to_update(advisories)
  end

  # --- main orchestration ---

  def test_no_vulnerabilities_emits_changes_made_false_and_no_update
    runner = FakeRunner.new
    Tempfile.create('gh_output') do |gh_out|
      ENV['GITHUB_OUTPUT'] = gh_out.path
      main(results: [], runner: runner.to_proc)
      assert_match(/changes_made=false/, File.read(gh_out.path))
    end
    assert_empty runner.commands, 'no commands run when nothing is vulnerable'
  ensure
    ENV.delete('GITHUB_OUTPUT')
  end

  def test_updates_each_vulnerable_gem_conservatively
    results = [
      unpatched(name: 'nokogiri', version: '1.13.0', id: 'CVE-1', patched: ['>= 1.13.6']),
      unpatched(name: 'rack', version: '2.0.0', id: 'CVE-2', patched: ['>= 2.0.1'])
    ]
    runner = FakeRunner.new(diff_dirty: true)

    Tempfile.create('gh_output') do |gh_out|
      ENV['GITHUB_OUTPUT'] = gh_out.path
      main(results: results, runner: runner.to_proc)
    end

    assert_includes runner.commands, 'BUNDLE_FROZEN=false bundle update --conservative nokogiri'
    assert_includes runner.commands, 'BUNDLE_FROZEN=false bundle update --conservative rack'
  ensure
    ENV.delete('GITHUB_OUTPUT')
  end

  def test_update_disables_frozen_mode
    results = [unpatched(name: 'loofah', version: '2.25.1', id: 'CVE-1', patched: ['>= 2.25.2'])]
    runner = FakeRunner.new(diff_dirty: true)

    Tempfile.create('gh_output') do |gh_out|
      ENV['GITHUB_OUTPUT'] = gh_out.path
      main(results: results, runner: runner.to_proc)
    end

    update = runner.commands.find { |c| c.include?('bundle update') }
    refute_nil update, 'expected a bundle update command to be run'
    assert_match(/\ABUNDLE_FROZEN=false /, update)
  ensure
    ENV.delete('GITHUB_OUTPUT')
  end

  def test_dirty_lockfile_emits_changes_made_true_and_writes_summary
    results = [unpatched(name: 'nokogiri', version: '1.13.0', id: 'CVE-1', patched: ['>= 1.13.6'])]
    runner = FakeRunner.new(diff_dirty: true)

    Tempfile.create('gh_output') do |gh_out|
      Tempfile.create('summary') do |summary|
        ENV['GITHUB_OUTPUT'] = gh_out.path
        ENV['PATCH_SUMMARY_FILE'] = summary.path
        main(results: results, runner: runner.to_proc)
        assert_match(/changes_made=true/, File.read(gh_out.path))
        assert_match(/`nokogiri` \(was 1\.13\.0\).*>= 1\.13\.6/, File.read(summary.path))
      end
    end
  ensure
    ENV.delete('GITHUB_OUTPUT')
    ENV.delete('PATCH_SUMMARY_FILE')
  end

  def test_clean_lockfile_emits_changes_made_false
    results = [unpatched(name: 'nokogiri', version: '1.13.0', id: 'CVE-1', patched: ['>= 2.0.0'])]
    runner = FakeRunner.new(diff_dirty: false)

    Tempfile.create('gh_output') do |gh_out|
      ENV['GITHUB_OUTPUT'] = gh_out.path
      main(results: results, runner: runner.to_proc)
      assert_match(/changes_made=false/, File.read(gh_out.path))
    end
  ensure
    ENV.delete('GITHUB_OUTPUT')
  end
end
# rubocop:enable Metrics/AbcSize,Metrics/ClassLength,Metrics/MethodLength,Style/Documentation
