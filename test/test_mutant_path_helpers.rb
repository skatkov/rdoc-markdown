# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMutantPathHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#class_dir' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#emit_pagefiles' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#initialize' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#turn_to_path' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#page_output_path' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#anchor' if respond_to?(:cover)

  GeneratorOptions = Struct.new(:op_dir, :root)
  FakePage = Struct.new(:relative_name, :base_name, :page_name, :description) do
    def text? = true

    def display? = true
  end
  DescriptionToSOnly = Struct.new(:value) do
    def to_s = value
  end
  FakeStore = Struct.new(:pages) do
    def all_classes_and_modules = []

    def all_files = pages
  end
  EmitPageProbe = Class.new(RDoc::Generator::Markdown) do
    public :emit_pagefiles
    public :setup

    attr_reader :finalize_calls, :markdown_inputs

    def initialize(*args)
      super
      @finalize_calls = []
      @markdown_inputs = []
    end

    private

    def markdownify(input)
      @markdown_inputs << input
      "markdown: #{input}"
    end

    def finalize_markdown(content, current_output_path: nil)
      @finalize_calls << [content, current_output_path]
      "final: #{current_output_path}: #{content}"
    end
  end

  def generator(root: nil)
    RDoc::Generator::Markdown.new(nil, GeneratorOptions.new(stable_tmpdir('generator'), root))
  end

  def source_file
    File.join(__dir__, 'data/example.rb')
  end

  def pages_root
    File.join(__dir__, 'data/pages')
  end

  def generate_docs(files:, title:, root: nil)
    dir = File.join(stable_tmpdir('generate-docs'), 'out')

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
    dir = stable_tmpdir('generate-from-store')
    generator = RDoc::Generator::Markdown.new(store, GeneratorOptions.new(dir, root))
    generator.generate
    dir
  end

  def test_class_dir_and_file_dir_are_nil
    assert_nil generator.class_dir
    assert_nil generator.file_dir
  end

  def test_initialize_sets_base_dir_and_leaves_classes_unset
    markdown_generator = generator

    assert_eql Pathname.pwd, markdown_generator.base_dir
    assert_nil markdown_generator.classes
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

  def test_emit_pagefiles_stringifies_page_descriptions_and_passes_page_path_to_finalize
    page = FakePage.new('docs/getting_started.rdoc', 'getting_started', 'Getting Started', DescriptionToSOnly.new('<h1>Intro</h1>'))
    probe = EmitPageProbe.new(FakeStore.new([page]), GeneratorOptions.new(stable_tmpdir('emit-page-probe'), nil))

    probe.setup
    probe.emit_pagefiles

    assert_eql ['<h1>Intro</h1>'], probe.markdown_inputs
    assert_eql [['markdown: <h1>Intro</h1>', 'docs/getting_started_rdoc.md']], probe.finalize_calls
    assert_eql 'final: docs/getting_started_rdoc.md: markdown: <h1>Intro</h1>',
               File.read(File.join(probe.instance_variable_get(:@output_dir), 'docs/getting_started_rdoc.md'))
  end
end
