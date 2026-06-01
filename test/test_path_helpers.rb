# frozen_string_literal: true

require_relative "test_helper"

require "csv"
require "rdoc/rdoc"
require "rdoc/markdown"

class TestPathHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown#class_dir"
  cover "RDoc::Generator::Markdown#emit_pagefiles"
  cover "RDoc::Generator::Markdown#initialize"
  cover "RDoc::Generator::Markdown#normalize_input_path_for_output"
  cover "RDoc::Generator::Markdown#resolve_output_path"
  cover "RDoc::Generator::Markdown#setup"
  cover "RDoc::Generator::Markdown#turn_to_path"
  cover "RDoc::Generator::Markdown#page_output_path"
  cover "RDoc::Generator::Markdown#converted_page_output_path"
  cover "RDoc::Generator::Markdown#copied_markdown_page?"
  cover "RDoc::Generator::Markdown#markdown_page?"
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

  def test_class_dir_and_file_dir_are_nil
    assert_nil generator.class_dir
    assert_nil generator.file_dir
  end

  def test_initialize_sets_base_dir_and_leaves_classes_unset
    markdown_generator = generator

    assert_eql Pathname.pwd, markdown_generator.base_dir
    assert_nil markdown_generator.classes
  end

  def test_turn_to_path_writes_nested_leaf_classes_to_nested_paths
    dir = generate_docs(files: File.join(__dir__, "data/namespaced_example.rb"), title: "namespaced test title")

    assert_false File.exist?(File.join(dir, "Ocean.md"))
    assert_false File.exist?(File.join(dir, "Ocean/Deep.md"))
    assert File.exist?(File.join(dir, "Ocean/Deep/Salmon.md"))
  end

  def test_page_output_path_rewrites_page_filenames_and_preserves_directories
    files = Dir[File.join(pages_root, "**/*.rdoc")]
    dir = generate_docs(files: files, title: "page test title", root: pages_root)

    assert File.exist?(File.join(dir, "README_rdoc.md"))
    assert File.exist?(File.join(dir, "guides/getting_started_rdoc.md"))

    index_rows = CSV.parse(File.read(File.join(dir, "index.csv")), headers: true)
    entries = index_rows.map { |row| [row["name"], row["type"], row["path"]] }

    assert_includes entries, ["README", "Page", "README_rdoc.md"]
    assert_includes entries, ["getting.started", "Page", "guides/getting_started_rdoc.md"]
  end

  def test_root_markdown_input_files_are_copied_without_renaming_or_rewriting
    root = stable_tmpdir("markdown-source")
    docs_dir = File.join(root, "docs")
    FileUtils.mkdir_p(docs_dir)

    readme = File.join(root, "README.md")
    history = File.join(root, "History.markdown")
    guide = File.join(docs_dir, "guide.md")
    root_link = File.join(docs_dir, "root_link.rdoc")
    direct_link = File.join(docs_dir, "direct_link.rdoc")

    readme_content = "# Project\n\n[Old API](classes/Foo.html)\n"
    history_content = "# History\n\n- Initial release  \n"
    guide_content = "# Guide\n\n{README}[../README.md]\n"

    File.write(readme, readme_content)
    File.write(history, history_content)
    File.write(guide, guide_content)
    File.write(root_link, "{README}[README_md.html]\n")
    File.write(direct_link, "{README}[README.md]\n")

    dir = generate_docs(files: [readme, history, guide, root_link, direct_link], title: "markdown copy test", root: root)

    assert_eql readme_content, File.binread(File.join(dir, "README.md"))
    assert_eql history_content, File.binread(File.join(dir, "History.markdown"))
    assert_eql "# Guide\n\n[README](../README.md)\n", File.read(File.join(dir, "docs/guide_md.md"))
    assert_eql "[README](../README.md)\n", File.read(File.join(dir, "docs/root_link_rdoc.md"))
    assert_eql "[README](../README.md)\n", File.read(File.join(dir, "docs/direct_link_rdoc.md"))

    assert_false File.exist?(File.join(dir, "README_md.md"))
    assert_false File.exist?(File.join(dir, "History_markdown.md"))
    assert_false File.exist?(File.join(dir, "docs/guide.md"))

    entries = CSV.parse(File.read(File.join(dir, "index.csv")), headers: true).map do |row|
      [row["name"], row["type"], row["path"]]
    end

    assert_includes entries, ["README", "Page", "README.md"]
    assert_includes entries, ["History.markdown", "Page", "History.markdown"]
    assert_includes entries, ["guide", "Page", "docs/guide_md.md"]
    assert_includes entries, ["root_link", "Page", "docs/root_link_rdoc.md"]
    assert_includes entries, ["direct_link", "Page", "docs/direct_link_rdoc.md"]
  end

  def test_root_markdown_copy_strips_absolute_root_path
    root = File.expand_path(stable_tmpdir("absolute-markdown-source"))
    readme = File.join(root, "README.md")
    File.write(readme, "# Copied\n")

    store = rdoc_store
    rdoc_page(store, relative_name: readme, comment: "= Rendered")

    dir = generate_from_store(store: store, root: root)

    assert_eql "# Copied\n", File.read(File.join(dir, "README.md"))
    assert_false File.exist?(File.join(dir, "README_md.md"))
  end

  def test_root_markdown_without_source_file_is_markdownified
    store = rdoc_store
    rdoc_page(store, relative_name: "missing-root-source-for-copy.md", comment: "= Rendered")

    dir = generate_from_store(store: store)

    assert_eql "# Rendered\n", File.read(File.join(dir, "missing-root-source-for-copy.md"))
  end

  def test_literal_links_to_copied_markdown_use_known_output_path
    root = stable_tmpdir("literal-markdown-link")
    docs_dir = File.join(root, "docs")
    FileUtils.mkdir_p(docs_dir)

    readme = File.join(root, "README.md")
    direct = File.join(docs_dir, "direct.md")
    File.write(readme, "# README\n")
    File.write(direct, "[README](README.md)\n")

    dir = generate_docs(files: [readme, direct], title: "literal markdown link", root: root)

    assert_eql "[README](../README.md)\n", File.read(File.join(dir, "docs/direct_md.md"))
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

    index_rows = CSV.parse(File.read(File.join(dir, "index.csv")), headers: true)
    entries = index_rows.map { |row| [row["name"], row["type"], row["path"]] }

    assert_includes entries, ["install.me", "Page", "guides/install_me_rdoc.md"]
    assert_includes entries, ["absolute", "Page", "guides/absolute_rdoc.md"]

    dotted_entries = CSV.parse(File.read(File.join(dotted_dir, "index.csv")), headers: true).map do |row|
      [row["name"], row["type"], row["path"]]
    end
    assert_includes dotted_entries, ["dotted", "Page", "guides/dotted_rdoc.md"]
    assert_includes dotted_entries, ["basename", "Page", "guides/basename_rdoc.md"]

    relative_entries = CSV.parse(File.read(File.join(relative_dir, "index.csv")), headers: true).map do |row|
      [row["name"], row["type"], row["path"]]
    end
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

    assert_eql "# Intro\n", File.read(File.join(dir, "docs/getting_started_rdoc.md"))
    assert_eql "[Intro](../guides/intro_rdoc.md#top)\n", File.read(File.join(dir, "docs/links_rdoc.md"))
    assert_eql "Dot path\n", File.read(File.join(dir, "docs/dot_rdoc.md"))
    assert_eql "Absolute path\n", File.read(File.join(dir, "docs/absolute_rdoc.md"))
    assert_eql "Windows path\n", File.read(File.join(dir, "docs/windows_rdoc.md"))

    entries = CSV.parse(File.read(File.join(dir, "index.csv")), headers: true).map { |row| [row["name"], row["type"], row["path"]] }
    assert_includes entries, ["dot", "Page", "docs/dot_rdoc.md"]
    assert_includes entries, ["absolute", "Page", "docs/absolute_rdoc.md"]
    assert_includes entries.map(&:last), "docs/windows_rdoc.md"
  end
end
