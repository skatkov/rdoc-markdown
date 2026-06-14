# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/rdoc"
require "rdoc/markdown"
require "rdiscount"

class TestGenerator < Minitest::Test
  cover "RDoc::Generator::Markdown#method_signature"
  cover "RDoc::Generator::Markdown#rbs_method_signature"
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
    refute_includes ruby_only_bird_doc, "#### `fly(String direction, Integer velocity) -> bool`"
    assert_includes bird_doc, "#### `new(String name) -> void`"
    assert_includes bird_doc, "#### `fly(String direction, Integer velocity) -> bool`"
    assert_includes bird_doc, "#### `build(Symbol name) -> String`"
    assert_includes bird_doc, "#### `build(String name) -> Bird`"
    assert_includes absolute_bird_doc, "#### `chirp(String sound) -> String`"
    assert_includes plain_bird_doc, "#### `chirp(sound)`"
    refute_includes bird_doc, "#### `new() -> singleton(Bird)`"
    refute_includes bird_doc, "#### `fly(direction, velocity)`"
    refute_includes bird_doc, "#### `build(name)`"
    refute_includes plain_bird_doc, "#### `chirp(String sound) -> String`"
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
    entries = CSV.parse(File.read(File.join(dir, "index.csv")), headers: true).map do |row|
      [row["name"], row["type"], row["path"]]
    end

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
