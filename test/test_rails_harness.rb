# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'tmpdir'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestRailsHarness < Minitest::Test
  def rails_root
    File.expand_path('../vendor/rails', __dir__)
  end

  def test_rails_docs_are_sdoc_like_and_well_formed
    skip 'vendor/rails is missing' unless Dir.exist?(rails_root)

    active_support_base = File.join(rails_root, 'activesupport/lib/active_support/hash_with_indifferent_access.rb')
    skip 'vendor/rails does not look like the expected repository' unless File.file?(active_support_base)

    files = Dir[File.join(rails_root, 'activesupport/lib/**/*.rb')]
    files.concat(Dir[File.join(rails_root, 'activerecord/lib/**/*.rb')])

    active_record_readme = File.join(rails_root, 'activerecord/README.rdoc')
    files << active_record_readme if File.file?(active_record_readme)

    out_dir = File.join(Dir.mktmpdir, 'rails-markdown')

    options = RDoc::Options.new
    options.setup_generator('markdown')
    options.verbosity = 0
    options.files = files
    options.op_dir = out_dir
    options.root = rails_root
    options.title = 'rails harness'

    RDoc::RDoc.new.document(options)

    hash_doc_path = File.join(out_dir, 'ActiveSupport/HashWithIndifferentAccess.md')
    assert File.exist?(hash_doc_path)

    hash_doc = File.read(hash_doc_path)
    assert_includes hash_doc, '# Hash With Indifferent Access'
    assert_includes hash_doc, 'rgb = ActiveSupport::HashWithIndifferentAccess.new'
    assert_includes hash_doc, 'Alias for: [`key?`](#method-i-key-3F)'
    refute_match(%r{\]\((?!https?://|mailto:|#)[^)]+\.html(?:[?#][^)]+)?\)}, hash_doc)

    base_doc = File.read(File.join(out_dir, 'ActiveRecord/Base.md'))
    assert_includes base_doc, '(../activerecord/README_rdoc.md)'
    refute_includes base_doc, '](../files/activerecord/README_rdoc.md)'

    csv_rows = CSV.parse(File.read(File.join(out_dir, 'index.csv')), headers: true)
    entries = csv_rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries,
                    ['ActiveSupport::HashWithIndifferentAccess', 'Class', 'ActiveSupport/HashWithIndifferentAccess.md']
    assert_includes entries, ['README', 'Page', 'activerecord/README_rdoc.md']

    refute(entries.any? { |name, _type, _path| name.match?(/([A-Za-z_][A-Za-z0-9_]*)::.*::\1::/) })
  end
end
