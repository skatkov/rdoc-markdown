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

    assert_nil index.signature_for(ruby_method(class_name: "Bird", method_name: "fly"))
  end

  def test_build_returns_empty_index_when_rbs_gem_is_unavailable
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
      signature = RDoc::Generator::Markdown::RbsSignatureIndex.build([ARGV.fetch(0)]).signature_for(method)

      raise "unexpected signature: #{signature}" if signature
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

    assert_equal "(String name) -> void", index.signature_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "new",
      singleton: true
    ))
    assert_equal "(String direction, Integer velocity) -> bool", index.signature_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "fly"
    ))
    assert_equal "(Symbol name) -> String", index.signature_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "build"
    ))
    assert_equal "(String name) -> Bird", index.signature_for(ruby_method(
      class_name: "Aviary::Bird",
      method_name: "build",
      singleton: true
    ))
    assert_equal "(String sound) -> String", index.signature_for(ruby_method(
      class_name: "AbsoluteBird",
      method_name: "chirp"
    ))
    assert_nil index.signature_for(ruby_method(class_name: "PlainBird", method_name: "chirp"))
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
