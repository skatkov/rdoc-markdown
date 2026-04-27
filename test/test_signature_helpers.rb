# frozen_string_literal: true

require_relative 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestSignatureHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#method_signature'
  cover 'RDoc::Generator::Markdown#merge_method_signature_arguments'
  cover 'RDoc::Generator::Markdown#normalized_method_params'
  cover 'RDoc::Generator::Markdown#split_signature_arguments_and_suffix'
  cover 'RDoc::Generator::Markdown#split_signature_list'
  cover 'RDoc::Generator::Markdown#extract_parameter_name'
  cover 'RDoc::Generator::Markdown#signature_part_mentions_name?'

  def generated_class_doc(methods)
    dir = stable_tmpdir('signature-docs')
    klass = build_rdoc_class(full_name: 'SignatureExamples', description: 'Signature docs')
    methods.each { |method| klass.add_method(method) }

    RDoc::Generator::Markdown.new(
      rdoc_store(classes: [klass], pages: []),
      generator_options(op_dir: dir)
    ).generate

    File.read(File.join(dir, 'SignatureExamples.md'))
  end

  def visible_method(name, signature: nil, params: nil)
    rdoc_method(name, visible: true, signature: signature, params: params)
  end

  def test_method_signatures_are_rendered_from_public_generation
    doc = generated_class_doc([
      visible_method('blank', signature: '  ', params: '(name)'),
      visible_method('nil_signature'),
      visible_method('returns', signature: ' -> bool', params: ''),
      visible_method('arrows', signature: '(Proc->bool)->bool', params: ''),
      visible_method('spaced', signature: '  ( String , Integer )  ', params: ''),
      visible_method('merged', signature: '(String, Integer) -> bool', params: '(name, count)'),
      visible_method('named', signature: '(name: String, count: Integer) -> bool', params: '(name, count)'),
      visible_method('mismatch', signature: '(String)', params: '(name, count)'),
      visible_method('bad_name', signature: '(String)', params: '(1name)'),
      visible_method('partial', signature: '(name: String, Integer)', params: '(name, count)'),
      visible_method('keyword', signature: '(bool)', params: '(flag:)'),
      visible_method('bad_second', signature: '(String, Integer)', params: '(name, 1count)'),
      visible_method('nested', signature: '(Array[String], Proc[(Integer) -> bool]) -> value', params: '(items, block)'),
      visible_method('forms', signature: '(Array, Hash, Proc, bool)', params: '(*items, **options, &block, keyword:)'),
      visible_method('single', signature: '(String)', params: '(x)'),
      visible_method('mentioned_splat', signature: '(*items: Array)', params: '(*items)'),
      visible_method('named_splat', signature: '(items: Array)', params: '(*items)')
    ])

    assert_includes doc, '#### `blank()`'
    assert_includes doc, '#### `nil_signature()`'
    assert_includes doc, '#### `returns -> bool`'
    assert_includes doc, '#### `arrows(Proc -> bool) -> bool`'
    assert_includes doc, '#### `spaced( String , Integer )`'
    assert_includes doc, '#### `merged(name: String, count: Integer) -> bool`'
    assert_includes doc, '#### `named(name: String, count: Integer) -> bool`'
    assert_includes doc, '#### `mismatch(String)`'
    assert_includes doc, '#### `bad_name(String)`'
    assert_includes doc, '#### `partial(name: name: String, count: Integer)`'
    assert_includes doc, '#### `keyword(flag: bool)`'
    assert_includes doc, '#### `bad_second(String, Integer)`'
    assert_includes doc, '#### `nested(items: Array[String], block: Proc[(Integer) -> bool]) -> value`'
    assert_includes doc, '#### `forms(*items: Array, **options: Hash, &block: Proc, keyword: bool)`'
    assert_includes doc, '#### `single(x: String)`'
    assert_includes doc, '#### `mentioned_splat(*items: Array)`'
    refute_includes doc, '#### `mentioned_splat(*items: *items: Array)`'
    assert_includes doc, '#### `named_splat(items: Array)`'
    refute_includes doc, '#### `named_splat(*items: items: Array)`'
  end
end
