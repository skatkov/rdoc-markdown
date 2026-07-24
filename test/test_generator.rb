# frozen_string_literal: true

require_relative "test_helper"

require "commonmarker"
require "nokogiri"
require "rdoc/rdoc"
require "rdoc/markdown"
require "rdiscount"

class TestGenerator < Minitest::Test
  cover "RDoc::Generator::Markdown#class_renderable?"
  cover "RDoc::Generator::Markdown#metadata_reference"
  cover "RDoc::Generator::Markdown#method_signature"
  cover "RDoc::Generator::Markdown#render_description"
  cover "RDoc::Generator::Markdown#setup"

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
    assert_includes duck_doc, <<~MARKDOWN.strip
      |  |  |
      | --- | --- |
      | **Inherits** | [Object](Object.md) |
      | **Includes** | [Waterfowl](Waterfowl.md) |
      | **Defined in** | example.rb |
    MARKDOWN
    assert_includes duck_doc, "| **Defined in** | example.rb |\n\nA duck is"
    assert_includes duck_doc, "[Waterfowl](Waterfowl.md)"
    assert_includes duck_doc, "[`Bird`](Bird.md)"
    refute_match(%r{\]\((?!https?://|mailto:|#)[^)]+\.html(?:#[^)]+)?\)}, duck_doc)
    assert_equal 1, duck_doc.scan("#### `MAX_VELOCITY`").count
    refute_includes duck_doc, "[](#"
    assert_includes duck_doc, "#### `useful? -> bool`"
    refute_includes duck_doc, "### Public Instance Methods\n\n"
    assert_includes duck_doc, "bird:\n\n- speak\n- fly"
    refute_includes duck_doc, "```\nbird::"

    bird_doc = File.read("#{dir}/Bird.md")
    refute_includes bird_doc, "| **Includes** |"
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

  def test_generator_renders_class_metadata_for_reopened_classes
    _workspace, root = project_fixture(
      "class-metadata",
      "lib/metadata  source—one.rb" => <<~RUBY,
        class MetadataBase; end
        module FirstMixin; end
        module SecondMixin; end

        class MetadataExample < MetadataBase
          include FirstMixin
          include SecondMixin
          include ExternalMixin
        end
      RUBY
      "lib/reopened.rb" => "class MetadataExample; end\n"
    )

    files = [File.join(root, "lib/metadata  source—one.rb"), File.join(root, "lib/reopened.rb")]
    dir = run_generator(files, "class metadata") { |options| options.root = root }
    metadata_doc = File.read(File.join(dir, "MetadataExample.md"))
    metadata_table = Nokogiri::HTML.fragment(Commonmarker.to_html(metadata_doc)).at_css("table")

    assert_includes metadata_doc, "| **Defined in** | lib/metadata  source—one.rb, lib/reopened.rb |"
    assert_eql [
      ["Inherits", "MetadataBase"],
      ["Includes", "FirstMixin, SecondMixin, ExternalMixin"],
      ["Defined in", "lib/metadata  source—one.rb, lib/reopened.rb"]
    ], metadata_table.css("tbody tr").map { |row| row.css("td").map(&:text) }
    assert_eql ["MetadataBase.md", "FirstMixin.md", "SecondMixin.md"],
      metadata_table.css("a").map { |link| link["href"] }

    first_mixin_doc = File.read(File.join(dir, "FirstMixin.md"))
    first_mixin_table = Nokogiri::HTML.fragment(Commonmarker.to_html(first_mixin_doc)).at_css("table")

    assert_eql [["Defined in", "lib/metadata  source—one.rb"]],
      first_mixin_table.css("tbody tr").map { |row| row.css("td").map(&:text) }
  end

  def test_generator_links_normalized_duplicate_superclass
    _workspace, root = project_fixture(
      "normalized-superclass",
      "lib/duplicates.rb" => <<~RUBY
        module Root
          class Thing
            def real_one; end
            def real_two; end
          end

          module Inner
            module Root
              class Thing
                # :category: Synthetic category
                def synthetic; end
              end

              class Undocumented; end
            end
          end
        end

        class Child < Root::Inner::Root::Thing; end
        class UnlinkedChild < Root::Inner::Root::Undocumented; end
      RUBY
    )

    dir = run_generator(File.join(root, "lib/duplicates.rb"), "normalized superclass") { |options| options.root = root }

    assert_path_exists File.join(dir, "Root/Thing.md")
    refute_path_exists File.join(dir, "Root/Inner/Root/Thing.md")
    thing_doc = File.read(File.join(dir, "Root/Thing.md"))
    entries = index_entries(dir)

    %w[real_one real_two].each do |method|
      assert_includes thing_doc, "#### `#{method}()`"
      assert_includes entries, ["Root::Thing.#{method}", "Method", "Root/Thing.md#method-i-#{method}"]
    end

    refute_includes thing_doc, "#### `synthetic()`"
    child_table = Nokogiri::HTML.fragment(Commonmarker.to_html(File.read(File.join(dir, "Child.md")))).at_css("table")
    child_inheritance = child_table.at_css("tbody tr")

    assert_eql ["Inherits", "Root::Inner::Root::Thing"], child_inheritance.css("td").map(&:text)
    assert_eql ["Root/Thing.md"], child_inheritance.css("a").map { |link| link["href"] }

    refute_path_exists File.join(dir, "Root/Undocumented.md")
    unlinked_child_table = Nokogiri::HTML.fragment(
      Commonmarker.to_html(File.read(File.join(dir, "UnlinkedChild.md")))
    ).at_css("table")
    unlinked_child_inheritance = unlinked_child_table.at_css("tbody tr")

    assert_eql ["Inherits", "Root::Inner::Root::Undocumented"], unlinked_child_inheritance.css("td").map(&:text)
    assert_empty unlinked_child_inheritance.css("a")
  end

  def test_generator_renders_untitled_sections_for_external_namespaces
    _workspace, root = project_fixture(
      "external-namespace-section",
      "lib/external.rb" => <<~RUBY
        class << External::Namespace
          # :section:
          # Untitled section body.
        end
      RUBY
    )

    dir = run_generator(File.join(root, "lib/external.rb"), "external namespace") { |options| options.root = root }

    markdown = File.read(File.join(dir, "External/Namespace.md"))
    assert_includes markdown, "Untitled section body."
    assert_includes index_entries(dir), ["External::Namespace", "Module", "External/Namespace.md"]
    refute_path_exists File.join(dir, "External.md")
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

  def test_generator_uses_rdoc_8_auto_discovered_sig_directory
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
    store.merge_rbs_signatures("SignatureExamples#sidecar" => ["(String) -> bool", "(Integer) -> bool"])

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

      class ExternalNamespace::HiddenClass # :nodoc:
      end
    RUBY

    dir = run_generator(source, "visibility test title")

    visible_doc = File.read(File.join(dir, "Visible.md"))
    entries = index_entries(dir)

    assert_true File.exist?(File.join(dir, "Visible.md"))
    assert_false File.exist?(File.join(dir, "HiddenClass.md"))
    assert_false File.exist?(File.join(dir, "HiddenModule.md"))
    assert_false File.exist?(File.join(dir, "ExternalNamespace.md"))
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
