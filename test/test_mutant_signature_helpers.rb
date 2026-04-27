# frozen_string_literal: true

require_relative 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMutantSignatureHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#method_signature'
  cover 'RDoc::Generator::Markdown#merge_method_signature_arguments'
  cover 'RDoc::Generator::Markdown#normalized_method_params'
  cover 'RDoc::Generator::Markdown#split_signature_arguments_and_suffix'
  cover 'RDoc::Generator::Markdown#split_signature_list'
  cover 'RDoc::Generator::Markdown#extract_parameter_name'
  cover 'RDoc::Generator::Markdown#signature_part_mentions_name?'

  def probe
    RDocMarkdownGeneratorProbes::SignatureProbe.new(nil, generator_options(op_dir: stable_tmpdir('signature-probe')))
  end

  def test_method_signature_returns_empty_parens_for_blank_signature
    assert_eql '()', probe.method_signature(rdoc_method(signature: '  ', params: '(name)'))
  end

  def test_method_signature_returns_empty_parens_for_nil_signature
    assert_eql '()', probe.method_signature(rdoc_method)
  end

  def test_method_signature_formats_return_only_signatures
    assert_eql ' -> bool', probe.method_signature(rdoc_method(signature: ' -> bool', params: ''))
  end

  def test_method_signature_normalizes_all_arrow_occurrences
    signature = probe.method_signature(rdoc_method(signature: '(Proc->bool)->bool', params: ''))

    assert_eql '(Proc -> bool) -> bool', signature
  end

  def test_method_signature_strips_outer_whitespace_after_normalizing_spaces
    signature = probe.method_signature(rdoc_method(signature: '  ( String , Integer )  ', params: ''))

    assert_eql '( String , Integer )', signature
  end

  def test_method_signature_merges_parameter_names_and_types
    signature = probe.method_signature(rdoc_method(signature: '(String, Integer) -> bool', params: '(name, count)'))

    assert_eql '(name: String, count: Integer) -> bool', signature
  end

  def test_method_signature_leaves_named_signatures_unchanged
    signature = probe.method_signature(rdoc_method(signature: '(name: String, count: Integer) -> bool', params: '(name, count)'))

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

  def test_normalized_method_params_collapses_internal_whitespace_runs
    assert_eql 'foo, bar', probe.normalized_method_params("(foo,\n   \tbar)")
  end

  def test_normalized_method_params_collapses_multiple_whitespace_runs
    assert_eql 'foo, bar, baz', probe.normalized_method_params("(foo,\n bar,\n\tbaz)")
  end

  def test_normalized_method_params_only_strips_balanced_wrapping_parens
    assert_eql 'foo)', probe.normalized_method_params('foo)')
    assert_eql '(foo', probe.normalized_method_params('(foo')
  end

  def test_normalized_method_params_returns_empty_string_for_nil
    assert_eql '', probe.normalized_method_params(nil)
  end

  def test_split_signature_arguments_and_suffix_handles_nested_parentheses
    args, suffix = probe.split_signature_arguments_and_suffix('(Array[String], Proc[(Integer) -> bool]) -> value')

    assert_eql 'Array[String], Proc[(Integer) -> bool]', args
    assert_eql ' -> value', suffix
  end

  def test_split_signature_arguments_and_suffix_requires_leading_open_paren
    assert_eql [nil, nil], probe.split_signature_arguments_and_suffix('Proc(String) -> value')
  end

  def test_split_signature_arguments_and_suffix_returns_nil_pair_for_unclosed_signature
    assert_eql [nil, nil], probe.split_signature_arguments_and_suffix('(String, Integer')
  end

  def test_split_signature_list_preserves_nested_delimiters
    parts = probe.split_signature_list('foo, [bar, baz], proc(x, y), {a: 1, b: 2}')

    assert_eql ['foo', '[bar, baz]', 'proc(x, y)', '{a: 1, b: 2}'], parts
  end

  def test_split_signature_list_resumes_top_level_splitting_after_closed_braces
    parts = probe.split_signature_list('{a: 1, b: 2}, tail')

    assert_eql ['{a: 1, b: 2}', 'tail'], parts
  end

  def test_split_signature_list_trims_trailing_space_before_split_commas
    parts = probe.split_signature_list('foo   , bar')

    assert_eql ['foo', 'bar'], parts
  end

  def test_split_signature_list_does_not_append_empty_trailing_part
    parts = probe.split_signature_list('foo,')

    assert_eql ['foo'], parts
  end

  def test_split_signature_list_trims_trailing_space_on_final_part
    parts = probe.split_signature_list('foo   ')

    assert_eql ['foo'], parts
  end

  def test_split_signature_list_ignores_unmatched_closing_delimiters_for_depth_tracking
    assert_eql ['foo)', 'bar'], probe.split_signature_list('foo), bar')
    assert_eql ['foo]', 'bar'], probe.split_signature_list('foo], bar')
    assert_eql ['foo}', 'bar'], probe.split_signature_list('foo}, bar')
  end

  def test_extract_parameter_name_handles_supported_parameter_forms
    assert_eql 'x', probe.extract_parameter_name('x')
    assert_eql 'name', probe.extract_parameter_name('name')
    assert_eql 'items', probe.extract_parameter_name('*items')
    assert_eql 'options', probe.extract_parameter_name('**options')
    assert_eql 'block', probe.extract_parameter_name('&block')
    assert_eql 'keyword', probe.extract_parameter_name('keyword:')
  end

  def test_extract_parameter_name_ignores_surrounding_whitespace
    assert_eql 'name', probe.extract_parameter_name('  name  ')
    assert_eql 'items', probe.extract_parameter_name('  *items  ')
  end

  def test_signature_part_mentions_name_uses_word_boundaries
    assert_true probe.signature_part_mentions_name?('name: String', 'name')
    assert_false probe.signature_part_mentions_name?('rename: String', 'name')
  end

  def test_signature_part_mentions_name_treats_name_as_literal_text
    assert_true probe.signature_part_mentions_name?('a+b: String', 'a+b')
  end
end
