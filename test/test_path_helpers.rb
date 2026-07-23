# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/rdoc"
require "rdoc/markdown"

class TestPathHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown#emit_pagefiles"
  cover "RDoc::Generator::Markdown#initialize"
  cover "RDoc::Generator::Markdown#normalize_input_path_for_output"
  cover "RDoc::Generator::Markdown#turn_to_path"
  cover "RDoc::Generator::Markdown#page_output_path"
  cover "RDoc::Generator::Markdown#anchor"

  def generator(root: nil)
    RDoc::Generator::Markdown.new(nil, generator_options(op_dir: stable_tmpdir("generator"), root: root))
  end

  def source_file
    File.join(__dir__, "data/example.rb")
  end

  def pages_root
    File.join(__dir__, "data/pages")
  end

  def generate_docs(files:, title:, root: nil)
    dir = File.join(stable_tmpdir("generate-docs"), "out")

    options = RDoc::Options.new
    options.setup_generator("markdown")
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
    dir = stable_tmpdir("generate-from-store")
    generator = RDoc::Generator::Markdown.new(store, generator_options(op_dir: dir, root: root))
    generator.generate
    dir
  end

  def test_initialize_leaves_classes_unset
    markdown_generator = generator

    assert_nil markdown_generator.classes
  end

  def test_turn_to_path_writes_nested_namespaces_to_nested_paths
    dir = generate_docs(files: File.join(__dir__, "data/namespaced_example.rb"), title: "namespaced test title")

    assert File.exist?(File.join(dir, "Ocean.md"))
    assert File.exist?(File.join(dir, "Ocean/Deep.md"))
    assert File.exist?(File.join(dir, "Ocean/Deep/Salmon.md"))
  end

  def test_page_output_path_rewrites_page_filenames_and_preserves_directories
    files = Dir[File.join(pages_root, "**/*.rdoc")]
    dir = generate_docs(files: files, title: "page test title", root: pages_root)

    assert File.exist?(File.join(dir, "README_rdoc.md"))
    assert File.exist?(File.join(dir, "guides/getting_started_rdoc.md"))

    entries = index_entries(dir)

    assert_includes entries, ["README", "Page", "README_rdoc.md"]
    assert_includes entries, ["getting.started", "Page", "guides/getting_started_rdoc.md"]
  end

  def test_page_output_path_strips_root_basename_prefix_from_page_paths
    store = rdoc_store
    dotted_root = File.expand_path(File.join(stable_tmpdir("root.with.dots"), "pages+v1"))
    relative_store = rdoc_store
    relative_root = "tmp/relative-root-pages"
    rdoc_page(store, relative_name: "pages/guides/install.me.rdoc", comment: "Install me")
    rdoc_page(store, relative_name: File.join(pages_root, "guides/absolute.rdoc"), comment: "Absolute install")
    rdoc_page(store, relative_name: File.join(dotted_root, "guides/dotted.rdoc"), comment: "Dotted root")
    rdoc_page(store, relative_name: "pages+v1/guides/basename.rdoc", comment: "Basename root")
    rdoc_page(
      relative_store,
      relative_name: File.expand_path(File.join(relative_root, "guides/relative.rdoc")),
      comment: "Relative root"
    )

    dir = generate_from_store(store: store, root: pages_root)
    dotted_dir = generate_from_store(store: store, root: dotted_root)
    relative_dir = generate_from_store(store: relative_store, root: relative_root)

    assert File.exist?(File.join(dir, "guides/install_me_rdoc.md"))
    assert File.exist?(File.join(dir, "guides/absolute_rdoc.md"))
    assert File.exist?(File.join(dotted_dir, "guides/dotted_rdoc.md"))
    assert File.exist?(File.join(dotted_dir, "guides/basename_rdoc.md"))
    assert File.exist?(File.join(relative_dir, "guides/relative_rdoc.md"))

    entries = index_entries(dir)

    assert_includes entries, ["install.me", "Page", "guides/install_me_rdoc.md"]
    assert_includes entries, ["absolute", "Page", "guides/absolute_rdoc.md"]

    dotted_entries = index_entries(dotted_dir)
    assert_includes dotted_entries, ["dotted", "Page", "guides/dotted_rdoc.md"]
    assert_includes dotted_entries, ["basename", "Page", "guides/basename_rdoc.md"]

    relative_entries = index_entries(relative_dir)
    assert_includes relative_entries, ["relative", "Page", "guides/relative_rdoc.md"]
  end

  def test_anchor_writes_method_anchor_tags_into_generated_docs
    dir = generate_docs(files: source_file, title: "anchor test title") do |options|
      options.visibility = :private
    end

    duck_doc = File.read(File.join(dir, "Duck.md"))

    assert_includes duck_doc, '<a id="method-i-useful-3F"></a>'
    assert_includes duck_doc, '<a id="method-i-quack"></a>'
  end

  def test_generate_writes_page_descriptions_to_markdown_paths
    store = rdoc_store
    rdoc_page(store, relative_name: "./docs/dot.rdoc", comment: "Dot path")
    rdoc_page(store, relative_name: "/docs/absolute.rdoc", comment: "Absolute path")
    rdoc_page(store, relative_name: 'docs\\windows.rdoc', comment: "Windows path")
    rdoc_page(store, relative_name: "guides/intro.rdoc", comment: "= Intro")
    rdoc_page(store, relative_name: "docs/getting_started.rdoc", comment: "= Intro")
    rdoc_page(store, relative_name: "docs/links.rdoc", comment: "{Intro}[guides/intro_rdoc.html#top]")

    dir = generate_from_store(store: store)

    assert_eql "<a id=\"label-Intro\"></a>\n# Intro\n", File.read(File.join(dir, "docs/getting_started_rdoc.md"))
    assert_eql "[Intro](../guides/intro_rdoc.md#top)\n", File.read(File.join(dir, "docs/links_rdoc.md"))
    assert_eql "Dot path\n", File.read(File.join(dir, "docs/dot_rdoc.md"))
    assert_eql "Absolute path\n", File.read(File.join(dir, "docs/absolute_rdoc.md"))
    assert_eql "Windows path\n", File.read(File.join(dir, "docs/windows_rdoc.md"))

    entries = index_entries(dir)
    assert_includes entries, ["dot", "Page", "docs/dot_rdoc.md"]
    assert_includes entries, ["absolute", "Page", "docs/absolute_rdoc.md"]
    assert_includes entries.map(&:last), "docs/windows_rdoc.md"
  end
end
