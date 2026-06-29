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
      index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rbs"], base_dir: source_dir)
    end

    assert_equal ["(String direction) -> bool"], index.signature_lines_for(ruby_method(
      class_name: "Bird",
      method_name: "fly"
    ))
  end

  def test_build_indexes_store_sidecar_signatures
    klass = build_rdoc_class(full_name: "Bird", description: "docs")
    method = rdoc_method("fly", params: "(direction)")
    klass.add_method(method)
    store = rdoc_store(classes: [klass])
    store.define_singleton_method(:rbs_signature_for) do |candidate|
      ["(String direction) -> bool"] if candidate.equal?(method)
    end

    index = RDoc::Generator::Markdown::RbsSignatureIndex.build(["bird.rb"], store: store)

    assert_true index.any?
    assert_equal ["(String direction) -> bool"], index.signature_lines_for(ruby_method(
      class_name: "Bird",
      method_name: "fly"
    ))
  end

  def test_rbs_signature_lines_from_method_uses_rdoc_8_type_signature_lines
    method = ruby_method(class_name: "Bird", method_name: "fly")
    method.define_singleton_method(:type_signature_lines) { ["(String direction) -> bool"] }

    assert_equal ["(String direction) -> bool"],
      RDoc::Generator::Markdown::RbsSignatureIndex.rbs_signature_lines_from_method(method)
  end

  def test_store_signature_lines_from_method_uses_rdoc_8_store_sidecar_signatures
    method = ruby_method(class_name: "Bird", method_name: "fly")
    store = Object.new
    store.define_singleton_method(:rbs_signature_for) do |candidate|
      raise "wrong method" unless candidate.equal?(method)

      ["(String direction) -> bool", "(Integer velocity) -> bool"]
    end

    assert_equal ["(String direction) -> bool", "(Integer velocity) -> bool"],
      RDoc::Generator::Markdown::RbsSignatureIndex.store_signature_lines_from_method(method, store: store)
  end

  def test_store_signature_lines_from_method_discards_blank_store_signature_lines
    method = ruby_method(class_name: "Bird", method_name: "fly")
    store = Object.new
    store.define_singleton_method(:rbs_signature_for) do |candidate|
      raise "wrong method" unless candidate.equal?(method)

      [nil, "  ", "(String direction) -> bool"]
    end

    assert_equal ["(String direction) -> bool"],
      RDoc::Generator::Markdown::RbsSignatureIndex.store_signature_lines_from_method(method, store: store)
  end

  def test_rbs_signature_lines_from_method_accepts_compact_non_whitespace_signatures
    method = ruby_method(class_name: "Bird", method_name: "name")
    method.define_singleton_method(:type_signature_lines) { ["String"] }

    assert_equal ["String"], RDoc::Generator::Markdown::RbsSignatureIndex.rbs_signature_lines_from_method(method)
  end

  def test_rbs_signature_lines_from_method_discards_blank_type_signature_lines
    method = ruby_method(class_name: "Bird", method_name: "name")
    method.define_singleton_method(:type_signature_lines) { [nil, "  ", "String"] }

    assert_equal ["String"], RDoc::Generator::Markdown::RbsSignatureIndex.rbs_signature_lines_from_method(method)
  end

  def test_rbs_signature_lines_from_method_ignores_blank_param_seq
    method = Struct.new(:param_seq).new("  ")

    assert_empty RDoc::Generator::Markdown::RbsSignatureIndex.rbs_signature_lines_from_method(method)
  end

  def test_store_signature_lines_from_method_prefers_inline_rdoc_8_type_signature_lines
    method = ruby_method(class_name: "Bird", method_name: "fly")
    method.define_singleton_method(:type_signature_lines) { ["(Symbol direction) -> bool"] }
    store = Object.new
    store.define_singleton_method(:rbs_signature_for) do |candidate|
      raise "wrong method" unless candidate.equal?(method)

      ["(String direction) -> bool"]
    end

    assert_equal ["(Symbol direction) -> bool"],
      RDoc::Generator::Markdown::RbsSignatureIndex.store_signature_lines_from_method(method, store: store)
  end

  def test_store_signature_lines_from_method_falls_back_to_store_when_inline_lines_are_empty
    method = ruby_method(class_name: "Bird", method_name: "fly")
    method.define_singleton_method(:type_signature_lines) { [nil, "  "] }
    store = Object.new
    store.define_singleton_method(:rbs_signature_for) do |candidate|
      raise "wrong method" unless candidate.equal?(method)

      ["(String direction) -> bool"]
    end

    assert_equal ["(String direction) -> bool"],
      RDoc::Generator::Markdown::RbsSignatureIndex.store_signature_lines_from_method(method, store: store)
  end

  def test_store_signature_lines_from_method_ignores_stores_without_sidecar_signature_support
    method = ruby_method(class_name: "Bird", method_name: "fly")

    assert_empty RDoc::Generator::Markdown::RbsSignatureIndex.store_signature_lines_from_method(method, store: Object.new)
  end

  def test_add_method_signature_ignores_blank_signatures
    signatures = {}
    klass = Struct.new(:full_name).new("Bird")
    method = Struct.new(:singleton, :name, :param_seq).new(false, "fly", "  ")

    RDoc::Generator::Markdown::RbsSignatureIndex.add_method_signature_lines(signatures, klass: klass, method: method, lines: ["  "])

    assert_empty signatures
  end

  def test_add_method_signature_ignores_nil_signatures
    signatures = {}
    klass = Struct.new(:full_name).new("Bird")
    method = Struct.new(:singleton, :name, :param_seq).new(false, "fly", nil)

    RDoc::Generator::Markdown::RbsSignatureIndex.add_method_signature_lines(signatures, klass: klass, method: method, lines: nil)

    assert_empty signatures
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
