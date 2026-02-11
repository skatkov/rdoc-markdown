# frozen_string_literal: true

require_relative 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/markdown'
require 'rdiscount'

class TestGenerator < Minitest::Test
  def source_file
    File.join(File.dirname(__FILE__), 'data/example.rb')
  end

  def run_generator(file, title)
    dir = File.join(Dir.mktmpdir, 'out')

    options = RDoc::Options.new
    options.setup_generator 'markdown'

    options.verbosity = 0
    options.files = [file]
    options.op_dir = dir
    options.title = title

    yield options if block_given?

    rdoc = RDoc::RDoc.new
    rdoc.document(options)

    dir
  end

  CLASSES = %w[Waterfowl Object Duck Bird]

  def test_generator
    dir = run_generator(source_file, 'test title')

    files = Dir[dir + '/*.md']

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
    rescue StandardError => e
      assert(False, "#{file} file is not formatted correctly: #{e}")
    end

    duck_doc = File.read("#{dir}/Duck.md")
    assert_includes duck_doc, '[`Waterfowl`](Waterfowl.md)'
    assert_includes duck_doc, '[`Bird`](Bird.md)'
    refute_match(%r{\]\((?!https?://|mailto:|#)[^)]+\.html(?:#[^)]+)?\)}, duck_doc)
    assert_equal 1, duck_doc.scan('#### `MAX_VELOCITY`').count
    refute_includes duck_doc, '[](#'
    assert_includes duck_doc, '#### `useful? -> bool`'

    bird_doc = File.read("#{dir}/Bird.md")
    refute_match(/\[¶\]/, bird_doc)
    refute_match(/\[↑\]\(#top\)/, bird_doc)
    assert_includes bird_doc, '##### Example'

    csv_data = File.read("#{dir}/index.csv")
    result = CSV.parse(csv_data, headers: true).map do |row|
      {
        name: row['name'],
        type: row['type'],
        path: row['path']
      }
    end

    assert_equal 15, result.count
    expected = [
      { name: 'Bird', type: 'Class', path: 'Bird.md' },
      { name: 'Bird.speak', type: 'Method', path: 'Bird.md#method-i-speak' },
      { name: 'Bird.fly', type: 'Method', path: 'Bird.md#method-i-fly' },
      { name: 'Duck', type: 'Class', path: 'Duck.md' },
      { name: 'Duck.speak', type: 'Method', path: 'Duck.md#method-i-speak' },
      { name: 'Duck.rubber_ducks', type: 'Method', path: 'Duck.md#method-c-rubber_ducks' },
      { name: 'Duck.new', type: 'Method', path: 'Duck.md#method-c-new' },
      { name: 'Duck.useful?', type: 'Method', path: 'Duck.md#method-i-useful-3F' },
      { name: 'Duck.MAX_VELOCITY', type: 'Constant', path: 'Duck.md#MAX_VELOCITY' },
      { name: 'Duck.domestic', type: 'Attribute', path: 'Duck.md#attribute-i-domestic' },
      { name: 'Duck.rubber', type: 'Attribute', path: 'Duck.md#attribute-i-rubber' },
      { name: 'Object', type: 'Class', path: 'Object.md' },
      {
        name: 'Object.DEFAULT_DUCK_VELOCITY',
        type: 'Constant',
        path: 'Object.md#DEFAULT_DUCK_VELOCITY'
      },
      { name: 'Waterfowl', type: 'Module', path: 'Waterfowl.md' },
      { name: 'Waterfowl.swim', type: 'Method', path: 'Waterfowl.md#method-i-swim' }
    ]

    assert_equal(expected, result)
  end

  def test_generator_with_private_visibility
    dir = run_generator(source_file, 'test title') do |options|
      options.visibility = :private
    end

    duck_doc = File.read("#{dir}/Duck.md")
    assert_includes duck_doc, '### Private Instance Methods'
    assert_includes duck_doc, '<a id="method-i-quack"></a>'

    csv_data = File.read("#{dir}/index.csv")
    result = CSV.parse(csv_data, headers: true).map do |row|
      {
        name: row['name'],
        type: row['type'],
        path: row['path']
      }
    end

    assert_equal 16, result.count
    assert_includes result, { name: 'Duck.quack', type: 'Method', path: 'Duck.md#method-i-quack' }
  end
end
