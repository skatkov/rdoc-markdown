# frozen_string_literal: true

require_relative 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMutantSignatureHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#method_signature' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#merge_method_signature_arguments' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#normalized_method_params' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#split_signature_arguments_and_suffix' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#split_signature_list' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#extract_parameter_name' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#signature_part_mentions_name?' if respond_to?(:cover)

  GeneratorOptions = Struct.new(:op_dir, :root)
  SignatureProbe = Class.new(RDoc::Generator::Markdown) do
    public :method_signature
    public :merge_method_signature_arguments
    public :normalized_method_params
    public :split_signature_arguments_and_suffix
    public :split_signature_list
    public :extract_parameter_name
    public :signature_part_mentions_name?
  end
  FakeMethod = Struct.new(:param_seq, :params)

  def probe
    SignatureProbe.new(nil, GeneratorOptions.new(Dir.mktmpdir, nil))
  end

  def test_method_signature_returns_empty_parens_for_blank_signature
    assert_eql '()', probe.method_signature(FakeMethod.new('  ', '(name)'))
  end

  def test_method_signature_returns_empty_parens_for_nil_signature
    assert_eql '()', probe.method_signature(FakeMethod.new(nil, '(name)'))
  end

  def test_method_signature_formats_return_only_signatures
    assert_eql ' -> bool', probe.method_signature(FakeMethod.new('->bool', ''))
  end

  def test_method_signature_normalizes_all_arrow_occurrences
    signature = probe.method_signature(FakeMethod.new('(Proc->bool)->bool', ''))

    assert_eql '(Proc -> bool) -> bool', signature
  end

  def test_method_signature_strips_outer_whitespace_after_normalizing_spaces
    signature = probe.method_signature(FakeMethod.new('  ( String , Integer )  ', ''))

    assert_eql '( String , Integer )', signature
  end

  def test_method_signature_merges_parameter_names_and_types
    signature = probe.method_signature(FakeMethod.new('(String, Integer) -> bool', '(name, count)'))

    assert_eql '(name: String, count: Integer) -> bool', signature
  end

  def test_method_signature_leaves_named_signatures_unchanged
    signature = probe.method_signature(FakeMethod.new('(name: String, count: Integer) -> bool', '(name, count)'))

    assert_eql '(name: String, count: Integer) -> bool', signature
  end

  def test_merge_method_signature_arguments_returns_original_for_mismatched_lists
    signature = probe.merge_method_signature_arguments('(String)', '(name, count)')

    assert_eql '(String)', signature
  end

  def test_merge_method_signature_arguments_returns_original_for_unextractable_names
    signature = probe.merge_method_signature_arguments('(String)', '(1name)')

    assert_eql '(String)', signature
  end

  def test_merge_method_signature_arguments_merges_when_only_some_parts_already_mention_names
    signature = probe.merge_method_signature_arguments('(name: String, Integer)', '(name, count)')

    assert_eql '(name: name: String, count: Integer)', signature
  end

  def test_merge_method_signature_arguments_formats_keyword_parameters_without_double_colons
    signature = probe.merge_method_signature_arguments('(bool)', '(flag:)')

    assert_eql '(flag: bool)', signature
  end

  def test_merge_method_signature_arguments_returns_original_when_any_name_is_unextractable
    signature = probe.merge_method_signature_arguments('(String, Integer)', '(name, 1count)')

    assert_eql '(String, Integer)', signature
  end

  def test_normalized_method_params_strips_wrapping_parens_and_whitespace
    assert_eql 'foo , bar', probe.normalized_method_params(' ( foo , bar ) ')
    assert_eql '', probe.normalized_method_params('()')
  end

  def test_split_signature_arguments_and_suffix_handles_nested_parentheses
    args, suffix = probe.split_signature_arguments_and_suffix('(Array[String], Proc[(Integer) -> bool]) -> value')

    assert_eql 'Array[String], Proc[(Integer) -> bool]', args
    assert_eql ' -> value', suffix
  end

  def test_split_signature_list_preserves_nested_delimiters
    parts = probe.split_signature_list('foo, [bar, baz], proc(x, y), {a: 1, b: 2}')

    assert_eql ['foo', '[bar, baz]', 'proc(x, y)', '{a: 1, b: 2}'], parts
  end

  def test_extract_parameter_name_handles_supported_parameter_forms
    assert_eql 'name', probe.extract_parameter_name('name')
    assert_eql 'items', probe.extract_parameter_name('*items')
    assert_eql 'options', probe.extract_parameter_name('**options')
    assert_eql 'block', probe.extract_parameter_name('&block')
    assert_eql 'keyword', probe.extract_parameter_name('keyword:')
  end

  def test_signature_part_mentions_name_uses_word_boundaries
    assert_true probe.signature_part_mentions_name?('name: String', 'name')
    assert_false probe.signature_part_mentions_name?('rename: String', 'name')
  end
end
