# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'tmpdir'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestActionpackRailtiesHarness < Minitest::Test
  def rails_root
    File.expand_path('../vendor/rails', __dir__)
  end

  def test_actionpack_and_railties_pages_have_stable_links
    skip 'vendor/rails is missing' unless Dir.exist?(rails_root)

    actionpack_readme = File.join(rails_root, 'actionpack/README.rdoc')
    railties_main = File.join(rails_root, 'railties/RDOC_MAIN.md')
    unless File.file?(actionpack_readme) && File.file?(railties_main)
      skip 'vendor/rails does not look like the expected repository'
    end

    files = Dir[File.join(rails_root, 'actionpack/lib/**/*.rb')]
    files.concat(Dir[File.join(rails_root, 'railties/lib/**/*.rb')])
    files << actionpack_readme
    files << File.join(rails_root, 'railties/README.rdoc')
    files << railties_main

    out_dir = File.join(Dir.mktmpdir, 'actionpack-railties-markdown')

    options = RDoc::Options.new
    options.setup_generator('markdown')
    options.verbosity = 0
    options.files = files
    options.op_dir = out_dir
    options.root = rails_root
    options.title = 'actionpack-railties harness'

    RDoc::RDoc.new.document(options)

    actionpack_readme_md = File.join(out_dir, 'actionpack/README_rdoc.md')
    railties_readme_md = File.join(out_dir, 'railties/README_rdoc.md')
    railties_main_md = File.join(out_dir, 'railties/RDOC_MAIN_md.md')

    assert File.exist?(actionpack_readme_md)
    assert File.exist?(railties_readme_md)
    assert File.exist?(railties_main_md)

    main_doc = File.read(railties_main_md)
    assert_includes main_doc, '[Action Pack](../actionpack/README_rdoc.md)'
    refute_includes main_doc, '](../files/'
    refute_includes main_doc, '](../classes/'
    refute_includes main_doc, '](../modules/'
    refute_match(%r{\]\((?!https?://|mailto:|#)[^)]+\.html(?:[?#][^)]+)?\)}, main_doc)

    main_doc.scan(%r{\]\((\.\./(?:actionpack|railties)/[^)#?]+(?:[?#][^)]+)?)\)}).flatten.each do |target|
      path = target.sub(/[?#].*\z/, '')
      assert File.exist?(File.expand_path(path, File.dirname(railties_main_md))), "missing target for #{target}"
    end

    rows = CSV.parse(File.read(File.join(out_dir, 'index.csv')), headers: true)
    entries = rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries, ['README', 'Page', 'actionpack/README_rdoc.md']
    assert_includes entries, ['README', 'Page', 'railties/README_rdoc.md']
    assert_includes entries, ['RDOC_MAIN', 'Page', 'railties/RDOC_MAIN_md.md']
  end
end
