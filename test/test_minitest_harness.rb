# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'tmpdir'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMinitestHarness < Minitest::Test
  def minitest_root
    File.expand_path('../vendor/minitest', __dir__)
  end

  def test_minitest_docs_are_aligned_and_readable
    skip 'vendor/minitest is missing' unless Dir.exist?(minitest_root)

    readme = File.join(minitest_root, 'README.rdoc')
    skip 'vendor/minitest does not look like the expected repository' unless File.file?(readme)

    files = Dir[File.join(minitest_root, 'lib/**/*.rb')]
    files.concat(Dir[File.join(minitest_root, '*.rdoc')])

    manifest = File.join(minitest_root, 'Manifest.txt')
    files << manifest if File.file?(manifest)

    out_dir = File.join(Dir.mktmpdir, 'minitest-markdown')

    options = RDoc::Options.new
    options.setup_generator('markdown')
    options.verbosity = 0
    options.files = files
    options.op_dir = out_dir
    options.root = minitest_root
    options.title = 'minitest harness'

    RDoc::RDoc.new.document(options)

    assert File.exist?(File.join(out_dir, 'README_rdoc.md'))
    assert File.exist?(File.join(out_dir, 'History_rdoc.md'))
    assert File.exist?(File.join(out_dir, 'Manifest_txt.md'))
    assert File.exist?(File.join(out_dir, 'Minitest/PathExpander.md'))

    readme_md = File.read(File.join(out_dir, 'README_rdoc.md'))

    assert_includes readme_md, '# minitest/{test,spec,benchmark}'
    assert_includes readme_md, '## DESCRIPTION:'
    assert_includes readme_md, '## FEATURES/PROBLEMS:'
    assert_includes readme_md, '## SYNOPSIS:'
    assert_includes readme_md, "class Meme\n  def i_can_has_cheezburger?"
    assert_includes readme_md, '[assertions](Minitest/Assertions.md)'
    refute_match(%r{\]\((?!https?://|mailto:|#)[^)]+\.html(?:[?#][^)]+)?\)}, readme_md)

    csv_rows = CSV.parse(File.read(File.join(out_dir, 'index.csv')), headers: true)

    entries = csv_rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries, ['README', 'Page', 'README_rdoc.md']
    assert_includes entries, ['History', 'Page', 'History_rdoc.md']
    assert_includes entries, ['Manifest', 'Page', 'Manifest_txt.md']
    assert_includes entries, ['Minitest::PathExpander', 'Class', 'Minitest/PathExpander.md']

    refute(entries.any? { |name, _type, _path| name.include?('VendoredPathExpander::Minitest::VendoredPathExpander') })
  end
end
