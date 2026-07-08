# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/rdoc"
require "rdoc/markdown"
require "rdiscount"

class TestGenerator < Minitest::Test
  cover "RDoc::Generator::Markdown#emit_csv_index"
  cover "RDoc::Generator::Markdown#main_page?"
  cover "RDoc::Generator::Markdown#method_signature"
  cover "RDoc::Generator::Markdown#page_type"
  cover "RDoc::Generator::Markdown#setup"
  cover "RDoc::Generator::Markdown::OptionsExtension#check_files"

  def source_file
    File.join(File.dirname(__FILE__), "data/example.rb")
  end

  def run_generator(files, title)
    dir = File.join(stable_tmpdir("generator-output"), "out")

    options = RDoc::Options.new
    options.setup_generator "markdown"

    options.verbosity = 0
    options.files = Array(files)
    options.op_dir = dir
    options.root = File.expand_path(File.dirname(Array(files).first.to_s)) unless Array(files).empty?
    options.title = title

    yield options if block_given?

    rdoc = RDoc::RDoc.new
    rdoc.document(options)

    dir
  end

  CLASSES = %w[Waterfowl Object Duck Bird]

  def test_generator
    dir = run_generator(source_file, "test title")

    files = Dir[dir + "/*.md"]

    assert_equal 4, files.count

    files.each do |file|
      p = Pathname.new(file)

      assert_includes CLASSES, p.basename.to_s.chomp(p.extname)
    end

    files.each do |file|
      contents = File.read(file)
      # puts "---file start---"
      # puts contents
      # puts "---file end---"

      refute_empty RDiscount.new(contents).to_html
    rescue => e
      assert(False, "#{file} file is not formatted correctly: #{e}")
    end

    duck_doc = File.read("#{dir}/Duck.md")
    assert_includes duck_doc, "[`Waterfowl`](Waterfowl.md)"
    assert_includes duck_doc, "[`Bird`](Bird.md)"
    refute_match(%r{\]\((?!https?://|mailto:|#)[^)]+\.html(?:#[^)]+)?\)}, duck_doc)
    assert_equal 1, duck_doc.scan("#### `MAX_VELOCITY`").count
    refute_includes duck_doc, "[](#"
    assert_includes duck_doc, "#### `useful? -> bool`"
    assert_includes duck_doc, "bird:\n\n- speak\n- fly"
    refute_includes duck_doc, "```\nbird::"

    bird_doc = File.read("#{dir}/Bird.md")
    refute_match(/\[¶\]/, bird_doc)
    refute_match(/\[↑\]\(#top\)/, bird_doc)
    assert_includes bird_doc, "##### Example"

    csv_data = File.read("#{dir}/index.csv")
    result = CSV.parse(csv_data, headers: true).map do |row|
      {
        name: row["name"],
        type: row["type"],
        path: row["path"]
      }
    end

    assert_equal 15, result.count
    expected = [
      {name: "Bird", type: "Class", path: "Bird.md"},
      {name: "Bird.speak", type: "Method", path: "Bird.md#method-i-speak"},
      {name: "Bird.fly", type: "Method", path: "Bird.md#method-i-fly"},
      {name: "Duck", type: "Class", path: "Duck.md"},
      {name: "Duck.speak", type: "Method", path: "Duck.md#method-i-speak"},
      {name: "Duck.rubber_ducks", type: "Method", path: "Duck.md#method-c-rubber_ducks"},
      {name: "Duck.new", type: "Method", path: "Duck.md#method-c-new"},
      {name: "Duck.useful?", type: "Method", path: "Duck.md#method-i-useful-3F"},
      {name: "Duck.MAX_VELOCITY", type: "Constant", path: "Duck.md#MAX_VELOCITY"},
      {name: "Duck.domestic", type: "Attribute", path: "Duck.md#attribute-i-domestic"},
      {name: "Duck.rubber", type: "Attribute", path: "Duck.md#attribute-i-rubber"},
      {name: "Object", type: "Class", path: "Object.md"},
      {
        name: "Object.DEFAULT_DUCK_VELOCITY",
        type: "Constant",
        path: "Object.md#DEFAULT_DUCK_VELOCITY"
      },
      {name: "Waterfowl", type: "Module", path: "Waterfowl.md"},
      {name: "Waterfowl.swim", type: "Method", path: "Waterfowl.md#method-i-swim"}
    ]

    assert_equal(expected, result)
  end

  def test_generator_auto_includes_root_pages_and_marks_configured_main_page
    workspace, = project_fixture(
      "readme-source",
      "README.md" => "# Project\n",
      "Guide.rdoc" => "= Guide\n",
      "CHANGELOG.md" => "# Changes\n",
      "HiStOrY.markdown" => "# History\n",
      "README.txt" => "Plain text\n",
      "docs/CHANGELOG.md" => "# Nested changes\n",
      "readme.markdown/nested.rb" => "class Nested; end\n"
    )

    dir = nil
    Dir.chdir(workspace) do
      dir = run_generator(["pkg/lib/project.rb", "pkg/docs/CHANGELOG.md"], "readme title") do |options|
        options.main_page = "README.md"
        options.root = Pathname("pkg")
      end
    end

    entries = index_entries(dir)

    assert_true File.exist?(File.join(dir, "README_md.md"))
    assert_true File.exist?(File.join(dir, "Guide_rdoc.md"))
    assert_true File.exist?(File.join(dir, "CHANGELOG_md.md"))
    assert_true File.exist?(File.join(dir, "HiStOrY_markdown.md"))
    assert_false File.exist?(File.join(dir, "README_txt.md"))
    assert_false File.exist?(File.join(dir, "pkg/README_md.md"))
    assert_false File.exist?(File.join(dir, "Nested.md"))
    assert_includes entries, ["README", "Readme", "README_md.md"]
    assert_includes entries, ["Guide", "Readme", "Guide_rdoc.md"]
    assert_includes entries, ["CHANGELOG", "Changelog", "CHANGELOG_md.md"]
    assert_includes entries, ["HiStOrY.markdown", "Changelog", "HiStOrY_markdown.md"]
    assert_includes entries, ["CHANGELOG", "Page", "docs/CHANGELOG_md.md"]
    refute_includes entries, ["README", "Page", "README_md.md"]
    refute_includes entries, ["Guide", "Page", "Guide_rdoc.md"]
    refute_includes entries, ["CHANGELOG", "Changelog", "docs/CHANGELOG_md.md"]
    refute(entries.any? { |name, _type, _path| name == "Nested" })
  end

  def test_generator_marks_configured_non_readme_main_page
    workspace, = project_fixture("configured-main-page-source", "Guide.rdoc" => "= Guide\n")

    dir = nil
    Dir.chdir(workspace) do
      dir = run_generator(["pkg/lib/project.rb", "pkg/Guide.rdoc"], "configured main page title") do |options|
        options.main_page = "Guide.rdoc"
        options.root = Pathname("pkg")
      end
    end

    entries = index_entries(dir)

    assert_includes entries, ["Guide", "Readme", "Guide_rdoc.md"]
  end

  def test_generator_marks_configured_nested_main_page
    workspace, = project_fixture("configured-nested-main-page-source", "docs/Guide.rdoc" => "= Guide\n")

    dir = nil
    Dir.chdir(workspace) do
      dir = run_generator(["pkg/lib/project.rb", "pkg/docs/Guide.rdoc"], "configured nested main page title") do |options|
        options.main_page = "pkg/docs/Guide.rdoc"
        options.root = Pathname("pkg")
      end
    end

    entries = index_entries(dir)

    assert_includes entries, ["Guide", "Readme", "docs/Guide_rdoc.md"]
  end

  def test_generator_marks_configured_root_changelog_main_page
    workspace, = project_fixture("configured-changelog-main-page-source", "CHANGELOG.md" => "# Changes\n")

    dir = nil
    Dir.chdir(workspace) do
      dir = run_generator(["pkg/lib/project.rb"], "configured changelog main page title") do |options|
        options.main_page = "CHANGELOG.md"
        options.root = Pathname("pkg")
      end
    end

    entries = index_entries(dir)

    assert_includes entries, ["CHANGELOG", "Readme", "CHANGELOG_md.md"]
  end

  def test_generator_does_not_duplicate_explicit_root_pages
    _workspace, root = project_fixture(
      "explicit-readme-source",
      "README.md" => "# Project\n",
      "Guide.rdoc" => "= Guide\n"
    )

    dir = run_generator(
      [File.join(root, "lib/project.rb"), File.join(root, "README.md")],
      "explicit readme title"
    ) do |options|
      options.root = root
    end

    entries = index_entries(dir)

    assert_equal 1, entries.count { |entry| entry == ["README", "Readme", "README_md.md"] }
    assert_includes entries, ["Guide", "Readme", "Guide_rdoc.md"]
  end

  def test_markdown_check_files_keeps_rdoc_file_validation
    root = File.expand_path(stable_tmpdir("missing-explicit-source"))
    source = File.join(root, "project.rb")
    missing = File.join(root, "missing.rb")
    readme = File.join(root, "README.md")
    license = File.join(root, "LICENSE.md")
    File.write(source, "class Project; end\n")
    File.write(readme, "# Project\n")
    File.write(license, "# License\n")

    options = RDoc::Options.new
    options.setup_generator("markdown")
    options.files = [source, missing]
    options.root = root

    options.check_files

    assert_includes options.files, source
    refute_includes options.files, missing
    assert_includes options.files, readme
    refute_includes options.files, license
  end

  def test_markdown_check_files_dedupes_and_validates_auto_root_pages_without_rewriting_inputs
    workspace = File.expand_path(stable_tmpdir("auto-root-page-validation-source"))
    root = File.join(workspace, "pkg")
    FileUtils.mkdir_p(File.join(root, "lib"))

    source = File.join(root, "lib/project.rb")
    readme = File.join(root, "README.md")
    guide = File.join(root, "Guide.md")
    relative_source = "pkg/lib/project.rb"
    relative_readme = "pkg/README.md"
    relative_guide = "pkg/Guide.md"
    File.write(source, "class Project; end\n")
    File.write(readme, "# Project\n")
    File.write(guide, "# Guide\n")

    File.chmod(0, guide)

    options = RDoc::Options.new
    options.setup_generator("markdown")
    options.files = [relative_source, relative_readme]
    options.root = Pathname("pkg")

    Dir.chdir(workspace) do
      options.check_files
    end

    assert_equal Pathname("pkg"), options.root
    assert_includes options.files, relative_source
    assert_includes options.files, relative_readme
    assert_equal 1, options.files.count(relative_readme)
    refute_includes options.files, source
    refute_includes options.files, readme
    refute_includes options.files, relative_guide unless File.readable?(guide)
  ensure
    File.chmod(0o644, guide) if guide && File.exist?(guide)
  end

  def test_generator_leaves_empty_file_list_to_rdoc_scan
    root = stable_tmpdir("empty-file-list-source")
    File.write(File.join(root, "project.rb"), "class Project; end\n")
    File.write(File.join(root, "README.md"), "# Project\n")

    dir = run_generator([], "empty file list title") do |options|
      options.root = root
    end

    entries = index_entries(dir)

    assert_true File.exist?(File.join(dir, "Project.md"))
    assert_true File.exist?(File.join(dir, "README_md.md"))
    assert_includes entries, ["Project", "Class", "Project.md"]
    assert_includes entries, ["README", "Readme", "README_md.md"]
  end

  def test_root_page_hook_does_not_change_other_generators
    root = stable_tmpdir("darkfish-source")
    source = File.join(root, "project.rb")
    dir = File.join(stable_tmpdir("darkfish-output"), "out")
    File.write(source, "class Project; end\n")
    File.write(File.join(root, "README.md"), "# Project\n")

    options = RDoc::Options.new
    options.setup_generator("darkfish")
    options.verbosity = 0
    options.files = [source]
    options.op_dir = dir
    options.root = root

    RDoc::RDoc.new.document(options)

    assert_empty Dir[File.join(dir, "**", "README*")]
  end

  def test_markdown_check_files_delegates_other_generators_to_rdoc_validation
    root = stable_tmpdir("darkfish-file-validation-source")
    source = File.join(root, "project.rb")
    missing = File.join(root, "missing.rb")
    File.write(source, "class Project; end\n")
    File.write(File.join(root, "README.md"), "# Project\n")

    options = RDoc::Options.new
    options.setup_generator("darkfish")
    options.files = [source, missing]
    options.root = root

    options.check_files

    assert_includes options.files, source
    refute_includes options.files, missing
    refute_includes options.files, File.join(root, "README.md")
  end

  def test_generator_with_private_visibility
    dir = run_generator(source_file, "test title") do |options|
      options.visibility = :private
    end

    duck_doc = File.read("#{dir}/Duck.md")
    assert_includes duck_doc, "### Private Instance Methods"
    assert_includes duck_doc, '<a id="method-i-quack"></a>'

    csv_data = File.read("#{dir}/index.csv")
    result = CSV.parse(csv_data, headers: true).map do |row|
      {
        name: row["name"],
        type: row["type"],
        path: row["path"]
      }
    end

    assert_equal 16, result.count
    assert_includes result, {name: "Duck.quack", type: "Method", path: "Duck.md#method-i-quack"}
  end

  def test_generator_preserves_args_metadata_alongside_call_seq
    dir = run_generator(source_file, "test title")

    bird_doc = File.read("#{dir}/Bird.md")

    assert_includes bird_doc, "#### `fly(direction: string, velocity: number) -> bool`"
    refute_includes bird_doc, "Arguments: `direction, velocity`"
  end

  def test_generator_uses_rbs_signatures_for_ruby_methods
    skip "rbs is not available" unless defined?(RBS::Parser)

    source_dir = stable_tmpdir("rbs-signature-source")
    ruby_file = File.join(source_dir, "bird.rb")
    rbs_file = File.join(source_dir, "bird.rbs")

    File.write(ruby_file, <<~RUBY)
      module Aviary
        class Bird
          def initialize(name)
          end

          def fly(direction, velocity)
          end

          def build(name)
          end

          def self.build(name)
          end
        end
      end

      class AbsoluteBird
        def chirp(sound)
        end
      end

      class PlainBird
        def chirp(sound)
        end
      end
    RUBY

    File.write(rbs_file, <<~RBS)
      module Aviary
        class Bird
          def initialize: (String name) -> void
          def fly: (String direction, Integer velocity) -> bool
          def build: (Symbol name) -> String
          def self.build: (String name) -> Bird
          def self.initialize: () -> singleton(Bird)
        end
      end

      class ::AbsoluteBird
        def chirp: (String sound) -> String
      end
    RBS

    ruby_only_dir = run_generator([ruby_file], "ruby signature title")
    dir = run_generator([ruby_file, rbs_file], "rbs signature title")
    ruby_only_bird_doc = File.read(File.join(ruby_only_dir, "Aviary/Bird.md"))
    bird_doc = File.read(File.join(dir, "Aviary/Bird.md"))
    absolute_bird_doc = File.read(File.join(dir, "AbsoluteBird.md"))
    plain_bird_doc = File.read(File.join(dir, "PlainBird.md"))

    assert_includes ruby_only_bird_doc, "#### `fly(direction, velocity)`"
    assert_includes bird_doc, "#### `new(String name) -> void`"
    assert_includes bird_doc, "#### `fly(String direction, Integer velocity) -> bool`"
    assert_includes bird_doc, "#### `build(Symbol name) -> String`"
    assert_includes bird_doc, "#### `build(String name) -> Bird`"
    assert_includes absolute_bird_doc, "#### `chirp(String sound) -> String`"
    assert_includes plain_bird_doc, "#### `chirp(sound)`"
    refute_includes bird_doc, "#### `new() -> singleton(Bird)`"
    refute_includes bird_doc, "#### `fly(direction, velocity)`"
    refute_includes bird_doc, "#### `build(name)`"
  end

  def test_generator_uses_relative_rbs_inputs_from_rdoc_start_directory
    source_dir = stable_tmpdir("relative-rbs-signature-source")

    File.write(File.join(source_dir, "bird.rb"), <<~RUBY)
      class Bird
        def fly(direction)
        end
      end
    RUBY

    File.write(File.join(source_dir, "bird.rbs"), <<~RBS)
      class Bird
        def fly: (String) -> bool
      end
    RBS

    dir = nil
    Dir.chdir(source_dir) do
      dir = run_generator(["bird.rb", "bird.rbs"], "relative rbs signature title")
    end
    bird_doc = File.read(File.join(dir, "Bird.md"))

    assert_includes bird_doc, "#### `fly(direction: String) -> bool`"
    refute_includes bird_doc, "#### `fly(direction)`"
  end

  def test_generator_setup_resolves_relative_rbs_files_from_initialize_directory
    skip "rbs is not available" unless defined?(RBS::Parser)

    source_dir = File.expand_path(stable_tmpdir("direct-relative-rbs-signature-source"))
    other_dir = File.expand_path(stable_tmpdir("direct-relative-rbs-signature-current"))
    output_dir = File.join(source_dir, "out")

    File.write(File.join(source_dir, "bird.rbs"), <<~RBS)
      class Bird
        def fly: (String) -> bool
      end
    RBS

    klass = build_rdoc_class(full_name: "Bird", description: "Bird docs")
    klass.add_method(rdoc_method("fly", params: "(direction)"))
    store = rdoc_store(classes: [klass])
    options = generator_options(op_dir: output_dir)
    options.files = ["bird.rbs"]

    Dir.chdir(source_dir) do
      generator = RDoc::Generator::Markdown.new(store, options)

      Dir.chdir(other_dir) do
        generator.generate
      end
    end

    bird_doc = File.read(File.join(output_dir, "Bird.md"))
    assert_includes bird_doc, "#### `fly(direction: String) -> bool`"
  end

  def test_generator_uses_rdoc_8_auto_discovered_sig_directory
    skip "RDoc 8 auto-discovers sig directories" if Gem.loaded_specs.fetch("rdoc").version < Gem::Version.new("8.0")

    source_dir = stable_tmpdir("auto-discovered-rbs-source")
    FileUtils.mkdir_p(File.join(source_dir, "lib"))
    FileUtils.mkdir_p(File.join(source_dir, "sig"))
    ruby_file = File.join(source_dir, "lib/bird.rb")

    File.write(ruby_file, <<~RUBY)
      class Bird
        def fly(direction)
        end
      end
    RUBY

    File.write(File.join(source_dir, "sig/bird.rbs"), <<~RBS)
      class Bird
        def fly: (String) -> bool
      end
    RBS

    dir = run_generator([ruby_file], "auto rbs signature title") do |options|
      options.root = source_dir
    end
    bird_doc = File.read(File.join(dir, "Bird.md"))

    assert_includes bird_doc, "#### `fly(direction: String) -> bool`"
    refute_includes bird_doc, "#### `fly(direction)`"
  end

  def test_generator_uses_store_sidecar_type_signatures
    dir = stable_tmpdir("sidecar-signature-generator")
    klass = build_rdoc_class(full_name: "SignatureExamples", description: "Signature docs")
    method = rdoc_method("sidecar", params: "(value)")
    klass.add_method(method)
    plain_klass = build_rdoc_class(full_name: "PlainSignatureExamples", description: "Plain docs")
    plain_klass.add_method(rdoc_method("plain", params: "(name)"))
    store = rdoc_store(classes: [klass, plain_klass], pages: [])
    store.define_singleton_method(:rbs_signature_for) do |candidate|
      ["(String) -> bool", "(Integer) -> bool"] if candidate.equal?(method)
    end

    RDoc::Generator::Markdown.new(store, generator_options(op_dir: dir)).generate
    doc = File.read(File.join(dir, "SignatureExamples.md"))
    plain_doc = File.read(File.join(dir, "PlainSignatureExamples.md"))

    assert_includes doc, "#### `sidecar(value: String) -> bool | (value: Integer) -> bool`"
    refute_includes doc, "#### `sidecar(value: String) -> bool | (Integer) -> bool`"
    refute_includes doc, "#### `sidecar(value)`"
    assert_includes plain_doc, "#### `plain(name)`"
  end

  def test_generator_omits_nodoc_and_invisible_code_objects
    source = File.join(stable_tmpdir("visibility-source"), "visibility_example.rb")
    File.write(source, <<~RUBY)
      class Visible
        def public_method; end
        def hidden_method; end # :nodoc:

        private

        def private_method; end
      end

      class HiddenClass # :nodoc:
        def leaked_method; end
      end

      module HiddenModule # :nodoc:
      end
    RUBY

    dir = run_generator(source, "visibility test title")

    visible_doc = File.read(File.join(dir, "Visible.md"))
    entries = index_entries(dir)

    assert_true File.exist?(File.join(dir, "Visible.md"))
    assert_false File.exist?(File.join(dir, "HiddenClass.md"))
    assert_false File.exist?(File.join(dir, "HiddenModule.md"))
    assert_includes visible_doc, "#### `public_method()`"
    refute_includes visible_doc, "hidden_method"
    refute_includes visible_doc, "private_method"
    assert_includes entries, ["Visible", "Class", "Visible.md"]
    assert_includes entries, ["Visible.public_method", "Method", "Visible.md#method-i-public_method"]
    refute(entries.any? { |name, _type, _path| name.include?("Hidden") })
    refute(entries.any? { |name, _type, _path| name.include?("hidden_method") })
    refute(entries.any? { |name, _type, _path| name.include?("private_method") })
  end

  def test_generator_writes_nested_namespaces_to_nested_paths
    dir = run_generator(File.join(__dir__, "data/namespaced_example.rb"), "namespaced test title")

    assert File.exist?(File.join(dir, "Ocean.md"))
    assert File.exist?(File.join(dir, "Ocean/Deep.md"))
    assert File.exist?(File.join(dir, "Ocean/Deep/Salmon.md"))
  end
end
