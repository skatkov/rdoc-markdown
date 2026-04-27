# frozen_string_literal: true

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

require_relative "support/mutant_setup"

class Minitest::Test
  private

  def stable_tmpdir(*parts)
    root = File.join(__dir__, '..', 'tmp', 'test-tmp')
    FileUtils.mkdir_p(root)

    prefix = ([self.class.name, name] + parts).map { |part| sanitize_tmp_segment(part) }.join('-')
    Dir.mktmpdir(prefix, root)
  end

  def sanitize_tmp_segment(part)
    part.to_s.gsub(/[^A-Za-z0-9._-]+/, '-')
  end
end
