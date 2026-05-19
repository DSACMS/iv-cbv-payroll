#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize,Metrics/ClassLength,Metrics/MethodLength,Style/Documentation

require 'minitest/autorun'
require 'json'
require 'tmpdir'

require_relative 'patch-dockerfile'

class PatchDockerfileTest < Minitest::Test
  EXISTING_MARKER_LINE = "#{AUTOFIX_MARKER} (managed automatically)\n".freeze
  STALE_MARKER_LINE = "# Auto-fix: OS package vulnerabilities detected by Trivy (managed automatically)\n"
  INSERTION_ANCHOR_LINE = "#{INSERTION_ANCHOR}\n".freeze

  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # --- helpers ---

  def write_json(name, data)
    path = File.join(@tmpdir, name)
    File.write(path, JSON.generate(data))
    path
  end

  def write_dockerfile(lines)
    path = File.join(@tmpdir, 'Dockerfile')
    File.write(path, lines.join)
    path
  end

  def run_main(trivy:, grype:, dockerfile:)
    out, = capture_io { main(trivy, grype, dockerfile) }
    out
  end

  def dockerfile_with_existing_block(packages)
    [
      "FROM debian AS base\n",
      EXISTING_MARKER_LINE,
      "# hadolint ignore=DL3008\n",
      "RUN apt-get update -qq && \\\n",
      "    apt-get install -y --no-install-recommends \\\n",
      *packages.map { |p| "      #{p} \\\n" },
      "    && \\\n",
      "    rm -rf /var/lib/apt/lists /var/cache/apt/archives\n",
      "\n",
      INSERTION_ANCHOR_LINE,
      "WORKDIR /rails\n"
    ]
  end

  def dockerfile_without_block
    [
      "FROM debian AS base\n",
      "\n",
      INSERTION_ANCHOR_LINE,
      "WORKDIR /rails\n"
    ]
  end

  def trivy_fixture(*pkg_names)
    {
      'Results' => [
        {
          'Class' => 'os-pkgs',
          'Vulnerabilities' => pkg_names.map { |n| { 'PkgName' => n, 'FixedVersion' => '1.0' } }
        }
      ]
    }
  end

  def grype_match(name:, type: 'deb', state: 'fixed', versions: ['1.0'])
    {
      'artifact' => { 'name' => name, 'type' => type },
      'vulnerability' => { 'fix' => { 'state' => state, 'versions' => versions } }
    }
  end

  def grype_fixture(*matches)
    { 'matches' => matches }
  end

  # --- tests ---

  def test_real_dockerfile_marker_matches_constant
    # Regression: drift between AUTOFIX_MARKER and the actual marker in
    # app/Dockerfile would cause the script to insert a duplicate block instead
    # of editing the existing one. Catch the drift here at test time.
    real_dockerfile = File.expand_path('../../app/Dockerfile', __dir__)
    skip("app/Dockerfile not found at #{real_dockerfile}") unless File.exist?(real_dockerfile)

    assert_includes File.read(real_dockerfile), AUTOFIX_MARKER,
                    'app/Dockerfile must contain the current AUTOFIX_MARKER'
  end

  def test_recognizes_existing_block_with_current_marker
    # Regression: if AUTOFIX_MARKER and the Dockerfile comment drift apart,
    # parse_autofix_block fails to find the block and a duplicate gets inserted.
    df = write_dockerfile(dockerfile_with_existing_block(%w[libcap2]))
    trivy = write_json('t.json', trivy_fixture)
    grype = write_json('g.json', grype_fixture(grype_match(name: 'libcap2')))

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_equal 1, content.scan(AUTOFIX_MARKER).size, 'exactly one autofix block expected'
    refute_match(/libcap2.*libcap2/m, content)
  end

  def test_does_not_duplicate_block_when_marker_matches_and_nothing_changes
    df = write_dockerfile(dockerfile_with_existing_block(%w[libcap2 libsystemd0]))
    original = File.read(df)
    trivy = write_json('t.json', trivy_fixture('libcap2'))
    grype = write_json('g.json', grype_fixture(grype_match(name: 'libsystemd0')))

    out = run_main(trivy: trivy, grype: grype, dockerfile: df)

    assert_equal original, File.read(df), 'Dockerfile must not change when union ⊆ existing'
    assert_match(/No new packages to add/, out)
  end

  def test_inserts_new_block_when_dockerfile_has_no_marker
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_fixture('libfoo'))
    grype = write_json('g.json', grype_fixture)

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, AUTOFIX_MARKER
    assert_includes content, "      libfoo \\\n"
    assert_equal 1, content.scan(AUTOFIX_MARKER).size
  end

  def test_does_not_recognize_stale_marker_and_creates_new_block
    # If someone forgets to bump the Dockerfile marker when bumping the constant,
    # the script should at least NOT silently edit the old (stale) block.
    # Documents the current behavior: stale marker is ignored, new block inserted.
    lines = [
      "FROM debian AS base\n",
      STALE_MARKER_LINE,
      "RUN apt-get update -qq && \\\n",
      "    apt-get install -y --no-install-recommends \\\n",
      "      oldpkg \\\n",
      "    && \\\n",
      "    rm -rf /var/lib/apt/lists /var/cache/apt/archives\n",
      "\n",
      INSERTION_ANCHOR_LINE
    ]
    df = write_dockerfile(lines)
    trivy = write_json('t.json', trivy_fixture('newpkg'))
    grype = write_json('g.json', grype_fixture)

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, 'oldpkg', 'stale block left untouched'
    assert_includes content, 'newpkg', 'new block added'
    assert_includes content, AUTOFIX_MARKER
  end

  def test_grype_filter_drops_non_os_artifact_types
    matches = [
      grype_match(name: 'libdeb1', type: 'deb'),
      grype_match(name: 'nokogiri', type: 'gem'),
      grype_match(name: 'lodash', type: 'npm'),
      grype_match(name: 'requests', type: 'python'),
      grype_match(name: 'log4j-core', type: 'java-archive'),
      grype_match(name: 'alpine-pkg', type: 'apk'),
      grype_match(name: 'rpm-pkg', type: 'rpm')
    ]
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_fixture)
    grype = write_json('g.json', grype_fixture(*matches))

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    %w[libdeb1 alpine-pkg rpm-pkg].each { |p| assert_includes content, "      #{p} \\\n" }
    %w[nokogiri lodash requests log4j-core].each { |p| refute_includes content, p }
  end

  def test_grype_filter_drops_unfixed_state
    matches = [
      grype_match(name: 'libfixed', state: 'fixed'),
      grype_match(name: 'libunfixed', state: 'not-fixed'),
      grype_match(name: 'libwontfix', state: 'wont-fix')
    ]
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_fixture)
    grype = write_json('g.json', grype_fixture(*matches))

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, 'libfixed'
    refute_includes content, 'libunfixed'
    refute_includes content, 'libwontfix'
  end

  def test_grype_filter_drops_empty_versions
    matches = [
      grype_match(name: 'libgood', versions: ['1.0']),
      grype_match(name: 'libempty', versions: [])
    ]
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_fixture)
    grype = write_json('g.json', grype_fixture(*matches))

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, 'libgood'
    refute_includes content, 'libempty'
  end

  def test_trivy_filter_only_includes_os_pkgs_class
    trivy_data = {
      'Results' => [
        { 'Class' => 'os-pkgs', 'Vulnerabilities' => [{ 'PkgName' => 'libos', 'FixedVersion' => '1.0' }] },
        { 'Class' => 'lang-pkgs', 'Vulnerabilities' => [{ 'PkgName' => 'somelibrary', 'FixedVersion' => '2.0' }] }
      ]
    }
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_data)
    grype = write_json('g.json', grype_fixture)

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, 'libos'
    refute_includes content, 'somelibrary'
  end

  def test_trivy_filter_drops_empty_fixed_version
    trivy_data = {
      'Results' => [
        { 'Class' => 'os-pkgs', 'Vulnerabilities' => [
          { 'PkgName' => 'libfixed', 'FixedVersion' => '1.0' },
          { 'PkgName' => 'libunfixed', 'FixedVersion' => '' }
        ] }
      ]
    }
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_data)
    grype = write_json('g.json', grype_fixture)

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, 'libfixed'
    refute_includes content, 'libunfixed'
  end

  def test_union_dedups_packages_flagged_by_both_scanners
    df = write_dockerfile(dockerfile_without_block)
    trivy = write_json('t.json', trivy_fixture('libshared'))
    grype = write_json('g.json', grype_fixture(grype_match(name: 'libshared')))

    run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_equal 1, content.scan(/^      libshared/).size
  end

  def test_stale_packages_kept_in_block
    df = write_dockerfile(dockerfile_with_existing_block(%w[libold libstill-flagged]))
    trivy = write_json('t.json', trivy_fixture('libstill-flagged'))
    grype = write_json('g.json', grype_fixture(grype_match(name: 'libnew')))

    out = run_main(trivy: trivy, grype: grype, dockerfile: df)

    content = File.read(df)
    assert_includes content, "      libold \\\n", 'stale package retained'
    assert_includes content, "      libstill-flagged \\\n", 'still-flagged package retained'
    assert_includes content, "      libnew \\\n", 'new package added'
    assert_match(/Already-patched packages no longer flagged.*libold/, out)
  end

  def test_emits_no_changes_when_union_subset_of_existing
    df = write_dockerfile(dockerfile_with_existing_block(%w[libcap2]))
    original = File.read(df)
    trivy = write_json('t.json', trivy_fixture('libcap2'))
    grype = write_json('g.json', grype_fixture)

    Tempfile.create('gh_output') do |f|
      ENV['GITHUB_OUTPUT'] = f.path
      run_main(trivy: trivy, grype: grype, dockerfile: df)
      assert_match(/changes_made=false/, File.read(f.path))
    end
    assert_equal original, File.read(df)
  ensure
    ENV.delete('GITHUB_OUTPUT')
  end

  def test_emits_changes_made_true_and_writes_summary_when_adding
    df = write_dockerfile(dockerfile_with_existing_block(%w[libcap2]))
    trivy = write_json('t.json', trivy_fixture('libcap2'))
    grype = write_json('g.json', grype_fixture(grype_match(name: 'libnew')))

    Tempfile.create('gh_output') do |gh_out|
      Tempfile.create('summary') do |summary|
        ENV['GITHUB_OUTPUT'] = gh_out.path
        ENV['PATCH_SUMMARY_FILE'] = summary.path
        run_main(trivy: trivy, grype: grype, dockerfile: df)
        assert_match(/changes_made=true/, File.read(gh_out.path))
        assert_match(/^- `libnew`/, File.read(summary.path))
      end
    end
  ensure
    ENV.delete('GITHUB_OUTPUT')
    ENV.delete('PATCH_SUMMARY_FILE')
  end
end
# rubocop:enable Metrics/AbcSize,Metrics/ClassLength,Metrics/MethodLength,Style/Documentation
