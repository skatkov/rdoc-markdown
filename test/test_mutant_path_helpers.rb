# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMutantPathHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#class_dir'
  cover 'RDoc::Generator::Markdown#emit_pagefiles'
  cover 'RDoc::Generator::Markdown#initialize'
  cover 'RDoc::Generator::Markdown#normalize_input_path_for_output'
  cover 'RDoc::Generator::Markdown#turn_to_path'
  cover 'RDoc::Generator::Markdown#page_output_path'
  cover 'RDoc::Generator::Markdown#anchor'

  def generator(root: nil)
    RDoc::Generator::Markdown.new(nil, generator_options(op_dir: stable_tmpdir('generator'), root: root))
  end

  def normalize_path_probe(root: nil)
    RDocMarkdownGeneratorProbes::NormalizePathProbe.new(nil, generator_options(op_dir: stable_tmpdir('normalize-path-probe'), root: root))
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
    generator = RDoc::Generator::Markdown.new(store, generator_options(op_dir: dir, root: root))
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

  def test_normalize_input_path_for_output_normalizes_dot_prefix_leading_slash_and_backslashes
    markdown_generator = normalize_path_probe

    assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output(Pathname.new('./guides\\install.me.rdoc'))
    assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output('/guides/install.me.rdoc')
  end

  def test_normalize_input_path_for_output_strips_root_basename_prefixes
    markdown_generator = normalize_path_probe(root: pages_root)

    assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output('pages/guides/install.me.rdoc')
  end

  def test_normalize_input_path_for_output_strips_absolute_root_using_normalized_windows_style_paths
    markdown_generator = normalize_path_probe(root: 'test\\data\\pages')
    input = 'C:\\workspace\\test\\data\\pages\\guides\\install.me.rdoc'

    File.stub(:expand_path, 'C:\\workspace\\test\\data\\pages') do
      assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output(input)
    end
  end

  def test_normalize_input_path_for_output_expands_root_relative_to_base_dir
    markdown_generator = normalize_path_probe(root: 'docs-root')
    markdown_generator.instance_variable_set(:@base_dir, Pathname.new('/custom/base'))
    input = 'C:\\workspace\\docs-root\\guides\\install.me.rdoc'

    File.stub(:expand_path, lambda { |path, base_dir = :missing|
      if path == 'docs-root' && base_dir == Pathname.new('/custom/base')
        'C:\\workspace\\docs-root'
      else
        'C:\\wrong-root'
      end
    }) do
      assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output(input)
    end
  end

  def test_normalize_input_path_for_output_uses_dot_when_root_is_nil
    markdown_generator = normalize_path_probe(root: nil)
    markdown_generator.instance_variable_set(:@base_dir, Pathname.new('/custom/base'))
    input = 'C:\\workspace\\dot-root\\guides\\install.me.rdoc'

    File.stub(:expand_path, lambda { |path, base_dir = :missing|
      if path == '.' && base_dir == Pathname.new('/custom/base')
        'C:\\workspace\\dot-root'
      else
        'C:\\wrong-root'
      end
    }) do
      assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output(input)
    end
  end

  def test_normalize_input_path_for_output_escapes_root_when_building_strip_pattern
    markdown_generator = normalize_path_probe(root: 'docs+root')
    input = 'C:\\workspace\\docs+root\\guides\\install.me.rdoc'

    File.stub(:expand_path, 'C:\\workspace\\docs+root') do
      assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output(input)
    end
  end

  def test_normalize_input_path_for_output_escapes_root_basename_when_stripping_prefix
    markdown_generator = normalize_path_probe(root: 'pages+root')

    assert_eql 'guides/install.me.rdoc', markdown_generator.normalize_input_path_for_output('pages+root/guides/install.me.rdoc')
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
    store = rdoc_store
    rdoc_page(store, relative_name: 'pages/guides/install.me.rdoc', comment: 'Install me')

    dir = generate_from_store(store: store, root: pages_root)

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
    store = rdoc_store
    rdoc_page(store, relative_name: 'docs/getting_started.rdoc', comment: '= Intro')
    probe = RDocMarkdownGeneratorProbes::EmitPageProbe.new(store, generator_options(op_dir: stable_tmpdir('emit-page-probe')))

    probe.setup
    probe.emit_pagefiles

    assert_eql ["\n<span id=\"label-Intro\" class=\"legacy-anchor\"></span>\n<h1 id=\"intro\"><a href=\"#intro\">Intro</a></h1>\n"], probe.markdown_inputs
    assert_eql [["markdown: \n<span id=\"label-Intro\" class=\"legacy-anchor\"></span>\n<h1 id=\"intro\"><a href=\"#intro\">Intro</a></h1>\n", 'docs/getting_started_rdoc.md']], probe.finalize_calls
    assert_eql "final: docs/getting_started_rdoc.md: markdown: \n<span id=\"label-Intro\" class=\"legacy-anchor\"></span>\n<h1 id=\"intro\"><a href=\"#intro\">Intro</a></h1>\n",
               File.read(File.join(probe.instance_variable_get(:@output_dir), 'docs/getting_started_rdoc.md'))
  end
end
