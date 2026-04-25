# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMutantPathHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#class_dir' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#turn_to_path' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#page_output_path' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#anchor' if respond_to?(:cover)

  GeneratorOptions = Struct.new(:op_dir, :root)
  FakePage = Struct.new(:relative_name, :base_name, :page_name, :description) do
    def text? = true

    def display? = true
  end
  FakeStore = Struct.new(:pages) do
    def all_classes_and_modules = []

    def all_files = pages
  end

  def generator(root: nil)
    RDoc::Generator::Markdown.new(nil, GeneratorOptions.new(Dir.mktmpdir, root))
  end

  def source_file
    File.join(__dir__, 'data/example.rb')
  end

  def pages_root
    File.join(__dir__, 'data/pages')
  end

  def generate_docs(files:, title:, root: nil)
    dir = File.join(Dir.mktmpdir, 'out')

    options = RDoc::Options.new
    options.setup_generator('markdown')
    options.verbosity = 0
    options.files = Array(files)
    options.op_dir = dir
    options.title = title
    options.root = root if root

    yield options if block_given?

    RDoc::RDoc.new.document(options)
    dir
  end

  def generate_from_store(store:, root: nil)
    dir = Dir.mktmpdir
    generator = RDoc::Generator::Markdown.new(store, GeneratorOptions.new(dir, root))
    generator.generate
    dir
  end

  def test_class_dir_and_file_dir_are_nil
    assert_nil generator.class_dir
    assert_nil generator.file_dir
  end

  def test_turn_to_path_writes_nested_namespaces_to_nested_paths
    dir = generate_docs(files: File.join(__dir__, 'data/namespaced_example.rb'), title: 'namespaced test title')

    assert File.exist?(File.join(dir, 'Ocean.md'))
    assert File.exist?(File.join(dir, 'Ocean/Deep.md'))
    assert File.exist?(File.join(dir, 'Ocean/Deep/Salmon.md'))
  end

  def test_page_output_path_rewrites_page_filenames_and_preserves_directories
    files = Dir[File.join(pages_root, '**/*.rdoc')]
    dir = generate_docs(files: files, title: 'page test title', root: pages_root)

    assert File.exist?(File.join(dir, 'README_rdoc.md'))
    assert File.exist?(File.join(dir, 'guides/getting_started_rdoc.md'))

    index_rows = CSV.parse(File.read(File.join(dir, 'index.csv')), headers: true)
    entries = index_rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries, ['README', 'Page', 'README_rdoc.md']
    assert_includes entries, ['getting.started', 'Page', 'guides/getting_started_rdoc.md']
  end

  def test_page_output_path_strips_root_basename_prefix_from_page_paths
    page = FakePage.new(
      'pages/guides/install.me.rdoc',
      'install.me',
      'install.me',
      'Install me'
    )

    dir = generate_from_store(store: FakeStore.new([page]), root: pages_root)

    assert File.exist?(File.join(dir, 'guides/install_me_rdoc.md'))

    index_rows = CSV.parse(File.read(File.join(dir, 'index.csv')), headers: true)
    entries = index_rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries, ['install.me', 'Page', 'guides/install_me_rdoc.md']
  end

  def test_anchor_writes_method_anchor_tags_into_generated_docs
    dir = generate_docs(files: source_file, title: 'anchor test title') do |options|
      options.visibility = :private
    end

    duck_doc = File.read(File.join(dir, 'Duck.md'))

    assert_includes duck_doc, '<a id="method-i-useful-3F"></a>'
    assert_includes duck_doc, '<a id="method-i-quack"></a>'
  end
end
