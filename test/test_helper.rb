# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  add_filter "/test/"
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "fileutils"
require "minitest/autorun"
require "minitest/strict"
require "tmpdir"

begin
  require "mutant/minitest/coverage"
rescue LoadError
  nil
end

require_relative "support/mutant"
require_relative "support/rdoc"

class Minitest::Test
  include RDocTestHelpers

  private

  def stable_tmpdir(*parts)
    root = File.join(__dir__, "..", "tmp", "test-tmp")
    FileUtils.mkdir_p(root)

    prefix = ([self.class.name, name] + parts).map { |part| sanitize_tmp_segment(part) }.join("-")
    Dir.mktmpdir(prefix, root)
  end

  def sanitize_tmp_segment(part)
    part.to_s.gsub(/[^A-Za-z0-9._-]+/, "-")
  end

  def with_rdoc_debug(value)
    set_rdoc_debug(value)
    yield
  ensure
    set_rdoc_debug(false)
  end

  def set_rdoc_debug(value)
    RDoc::Options.new.parse([value ? "--debug" : "--no-debug"])
  end
end
