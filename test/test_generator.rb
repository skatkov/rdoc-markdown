# frozen_string_literal: true

require_relative "test_helper"

require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestGenerator < MiniTest::Test
  def source_file
    File.join(File.dirname(__FILE__), "../docs/example.rb")
  end

  def run_generator(file, title)
    dir = File.join(Dir.mktmpdir, "out")

    options = RDoc::Options.new
    options.setup_generator "markdown"

    options.verbosity = 0
    options.files = [file]
    options.op_dir = dir
    options.title = title

    yield options if block_given?

    rdoc = RDoc::RDoc.new
    rdoc.document(options)

    dir
  end

  def test_generator
    dir = run_generator(source_file, 'test title')

    classes = ['Waterfowl', 'Object', 'Duck', 'Bird']
    Dir[dir+"/*.html"].each do |file|
      p = Pathname.new(file)

      assert_includes classes, p.basename.to_s.chomp(p.extname)
    end
  end
end
