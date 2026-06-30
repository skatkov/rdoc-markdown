# frozen_string_literal: true

require_relative "test_helper"

require "open3"
require "rbconfig"
require "rdoc/markdown"

class TestRbsSignatureIndex < Minitest::Test
  cover "RDoc::Generator::Markdown::RbsSignatureIndex*"

  def rbs_file(source)
    path = File.join(stable_tmpdir("rbs-signature-index"), "bird.rbs")
    File.write(path, source)
    path
  end

  def ruby_method(class_name:, method_name:, singleton: false)
    klass = build_rdoc_class(full_name: class_name, description: "docs")
    method = rdoc_method(method_name, params: "(value)")
    method.singleton = singleton
    klass.add_method(method)
    method
  end

  def store_with_method(type_signature_lines: nil, sidecar_lines: nil, sidecar: true)
    klass = build_rdoc_class(full_name: "Bird", description: "docs")
    method = rdoc_method("fly", params: "(direction)")
    method.define_singleton_method(:type_signature_lines) { type_signature_lines } unless type_signature_lines.nil?
    klass.add_method(method)
    store = rdoc_store(classes: [klass])

    if sidecar
      store.define_singleton_method(:rbs_signature_for) do |candidate|
        raise "wrong method" unless candidate.equal?(method)

        sidecar_lines
      end
    end

    [store, method]
  end

  def with_rdoc_parser_for(parser_factory)
    original_for = RDoc::Parser.method(:for)
    RDoc::Parser.define_singleton_method(:for) do |top_level, *|
      parser_factory.call(top_level)
    end

    yield
  ensure
    RDoc::Parser.define_singleton_method(:for, original_for)
  end

  def test_build_returns_empty_index_without_rbs_files
    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"])

    assert_empty index.signature_lines_for(ruby_method(class_name: "Bird", method_name: "fly"))
    assert_false index.any?
  end

  def test_build_returns_empty_index_when_rbs_gem_is_unavailable
    skip "RDoc 8 requires rbs while loading rdoc/rdoc" if Gem.loaded_specs.fetch("rdoc").version >= Gem::Version.new("8.0")

    file = rbs_file(<<~RBS)
      class Bird
        def fly: (String value) -> bool
      end
    RBS

    output, status = run_without_rbs_gem(<<~'RUBY', file)
      require "rdoc/rdoc"

      class RDoc::Generator::Markdown
      end

      require "rdoc/generator/markdown/rbs_signature_index"

      rbs_parser = RDoc::Parser.parsers.any? do |regexp, parser|
        regexp.match?("bird.rbs") && parser.name == "RDoc::Parser::RBS"
      end
      raise "RBS parser should not be available" if rbs_parser

      parent = Struct.new(:full_name).new("Bird")
      method = Struct.new(:parent, :singleton, :name).new(parent, false, "fly")
      signature = RDoc::Generator::Markdown::RbsSignatureIndex.build([ARGV.fetch(0)]).signature_lines_for(method)

      raise "unexpected signature: #{signature}" unless signature.empty?
    RUBY

    assert_true status.success?, output
  end

  def test_build_indexes_rbs_signatures_from_rdoc_parser_output
    file = rbs_file(<<~RBS)
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

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build([file])

    assert_true index.any?
    assert_equal ["(String name) -> void"], index.signature_lines_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "new",
      singleton: true
    ))
    assert_equal ["(String direction, Integer velocity) -> bool"], index.signature_lines_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "fly"
    ))
    assert_equal ["(Symbol name) -> String"], index.signature_lines_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "build"
    ))
    assert_equal ["(String name) -> Bird"], index.signature_lines_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "build",
      singleton: true
    ))
    assert_equal ["(String sound) -> String"], index.signature_lines_for(ruby_method(
      class_name: "AbsoluteBird",
      method_name: "chirp"
    ))
    assert_empty index.signature_lines_for(ruby_method(class_name: "PlainBird", method_name: "chirp"))
  end

  def test_build_indexes_type_signature_lines_from_rdoc_parser_output
    file = rbs_file("")
    test = self

    parser_factory = ->(top_level) do
      Object.new.tap do |parser|
        parser.define_singleton_method(:scan) do
          store = top_level.store
          klass = test.build_rdoc_class(full_name: "Bird", description: "docs")
          method = test.rdoc_method("fly", params: "(direction)")
          method.define_singleton_method(:type_signature_lines) { ["(String direction) -> bool"] }
          klass.add_method(method)
          klass.store = store
          store.classes_hash[klass.full_name] = klass
        end
      end
    end

    with_rdoc_parser_for(parser_factory) do
      index = RDoc::Generator::Markdown::RbsSignatureIndex.build([file])

      assert_equal ["(String direction) -> bool"], index.signature_lines_for(ruby_method(
        class_name: "Bird",
        method_name: "fly"
      ))
    end
  end

  def test_build_resolves_relative_rbs_files_against_base_dir
    source_dir = stable_tmpdir("relative-rbs-signature-index")
    current_dir = stable_tmpdir("relative-rbs-current")
    File.write(File.join(source_dir, "bird.rbs"), <<~RBS)
      class Bird
        def fly: (String direction) -> bool
      end
    RBS

    index = nil
    Dir.chdir(current_dir) do
      index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rbs"], source_dir)
    end

    assert_equal ["(String direction) -> bool"], index.signature_lines_for(ruby_method(
      class_name: "Bird",
      method_name: "fly"
    ))
  end

  def test_build_indexes_store_sidecar_signatures
    store, method = store_with_method(sidecar_lines: ["(String direction) -> bool"])

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_true index.any?
    assert_equal ["(String direction) -> bool"], index.signature_lines_for(method)
  end

  def test_build_indexes_store_inline_type_signature_lines
    store, method = store_with_method(type_signature_lines: ["(String direction) -> bool"], sidecar: false)

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_true index.any?
    assert_equal ["(String direction) -> bool"], index.signature_lines_for(method)
  end

  def test_build_indexes_store_sidecar_overloads
    store, method = store_with_method(sidecar_lines: ["(String direction) -> bool", "(Integer velocity) -> bool"])

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_equal ["(String direction) -> bool", "(Integer velocity) -> bool"], index.signature_lines_for(method)
  end

  def test_build_discards_blank_store_sidecar_signature_lines
    store, method = store_with_method(sidecar_lines: [nil, "  ", "(String direction) -> bool"])

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_equal ["(String direction) -> bool"], index.signature_lines_for(method)
  end

  def test_build_ignores_nil_store_sidecar_signature
    store, method = store_with_method(sidecar_lines: nil)

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_false index.any?
    assert_empty index.signature_lines_for(method)
  end

  def test_build_accepts_compact_inline_type_signature_lines
    store, method = store_with_method(type_signature_lines: ["String"], sidecar: false)

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_equal ["String"], index.signature_lines_for(method)
  end

  def test_build_discards_blank_inline_type_signature_lines
    store, method = store_with_method(type_signature_lines: [nil, "  "], sidecar: false)

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_false index.any?
    assert_empty index.signature_lines_for(method)
  end

  def test_build_prefers_inline_type_signature_lines_over_store_sidecar_signatures
    store, method = store_with_method(
      type_signature_lines: ["(Symbol direction) -> bool"],
      sidecar_lines: ["(String direction) -> bool"]
    )

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_equal ["(Symbol direction) -> bool"], index.signature_lines_for(method)
  end

  def test_build_falls_back_to_store_when_inline_type_signature_lines_are_blank
    store, method = store_with_method(
      type_signature_lines: [nil, "  "],
      sidecar_lines: ["(String direction) -> bool"]
    )

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_equal ["(String direction) -> bool"], index.signature_lines_for(method)
  end

  def test_build_ignores_store_methods_without_type_signatures
    store, method = store_with_method(sidecar: false)

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], nil, store)

    assert_false index.any?
    assert_empty index.signature_lines_for(method)
  end

  def run_without_rbs_gem(source, *arguments)
    gem_home = stable_tmpdir("empty-gems")
    rdoc_lib = File.join(Gem.loaded_specs.fetch("rdoc").full_gem_path, "lib")
    env = {
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_LOCKFILE" => nil,
      "BUNDLER_SETUP" => nil,
      "BUNDLER_VERSION" => nil,
      "GEM_HOME" => gem_home,
      "GEM_PATH" => gem_home,
      "RUBYLIB" => nil,
      "RUBYOPT" => ""
    }
    command = [
      RbConfig.ruby,
      "-I#{File.expand_path("../lib", __dir__)}",
      "-I#{rdoc_lib}",
      "-e",
      source,
      *arguments
    ]
    stdout, stderr, status = Open3.capture3(env, *command)

    [stdout + stderr, status]
  end
end
