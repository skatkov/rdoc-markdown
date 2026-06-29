# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/rdoc"
require "rdoc/markdown"

class TestSignatureHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown#method_signature"
  cover "RDoc::Generator::Markdown#types_available?"
  cover "RDoc::Generator::Markdown#merge_method_signature_arguments"
  cover "RDoc::Generator::Markdown#normalized_method_params"
  cover "RDoc::Generator::Markdown#split_signature_arguments_and_suffix"
  cover "RDoc::Generator::Markdown#split_signature_list"
  cover "RDoc::Generator::Markdown#extract_parameter_name"
  cover "RDoc::Generator::Markdown#signature_part_mentions_name?"

  def generated_class_doc(methods)
    dir = stable_tmpdir("signature-docs")
    klass = build_rdoc_class(full_name: "SignatureExamples", description: "Signature docs")
    methods.each { |method| klass.add_method(method) }

    RDoc::Generator::Markdown.new(
      rdoc_store(classes: [klass], pages: []),
      generator_options(op_dir: dir)
    ).generate

    File.read(File.join(dir, "SignatureExamples.md"))
  end

  def visible_method(name, signature: nil, params: nil)
    rdoc_method(name, visible: true, signature: signature, params: params)
  end

  def test_method_signatures_are_rendered_from_public_generation
    nil_param_seq = visible_method("nil_param_seq")
    nil_param_seq.define_singleton_method(:param_seq) { nil }

    doc = generated_class_doc([
      visible_method("blank", signature: "  ", params: "(name)"),
      visible_method("nil_signature"),
      nil_param_seq,
      visible_method("empty_signature_named_params", signature: "()", params: "(name)"),
      visible_method("returns", signature: " -> bool", params: ""),
      visible_method("returns_proc", signature: " -> Proc[(Integer) -> bool]", params: "(block)"),
      visible_method("arrows", signature: "(Proc->bool)->bool", params: ""),
      visible_method("spaced", signature: "  ( String , Integer )  ", params: ""),
      visible_method("trimmed_parts", signature: "(String , Integer)", params: "(name, count)"),
      visible_method("merged", signature: "(String, Integer) -> bool", params: "(name, count)"),
      visible_method("named", signature: "(name: String, count: Integer) -> bool", params: "(name, count)"),
      visible_method("mismatch", signature: "(String)", params: "(name, count)"),
      visible_method("bad_name", signature: "(String)", params: "(1name)"),
      visible_method("partial", signature: "(name: String, Integer)", params: "(name, count)"),
      visible_method("keyword", signature: "(bool)", params: "(flag:)"),
      visible_method("bad_second", signature: "(String, Integer)", params: "(name, 1count)"),
      visible_method("nested", signature: "(Array[String], Proc[(Integer) -> bool]) -> value", params: "(items, block)"),
      visible_method("nested_first", signature: "((String), Integer)", params: "(wrapped, count)"),
      visible_method("paren_comma", signature: "(Tuple(String, Integer), Float)", params: "(tuple, value)"),
      visible_method("bracket_comma", signature: "(Array[String, Integer], Float)", params: "(items, value)"),
      visible_method("brace_comma", signature: "(Hash{String, Integer}, Float)", params: "(mapping, value)"),
      visible_method("forms", signature: "(Array, Hash, Proc, bool)", params: "(*items, **options, &block, keyword:)"),
      visible_method("single", signature: "(String)", params: "(x)"),
      visible_method("mentioned_splat", signature: "(*items: Array)", params: "(*items)"),
      visible_method("named_splat", signature: "(items: Array)", params: "(*items)"),
      visible_method("named_block", signature: "(block: Proc)", params: "(&block)"),
      visible_method("nil_params", signature: "(String)", params: nil),
      visible_method("spaced_params", signature: "(String, Integer, Float)", params: " \n( name,\n\tcount,\n value )\n "),
      visible_method("open_only", signature: "(String)", params: "(name"),
      visible_method("close_only", signature: "(String)", params: "name)")
    ])

    assert_includes doc, "#### `blank()`"
    assert_includes doc, "#### `nil_signature()`"
    assert_includes doc, "#### `nil_param_seq()`"
    assert_includes doc, "#### `empty_signature_named_params()`"
    refute_includes doc, "#### `empty_signature_named_params(name: )`"
    assert_includes doc, "#### `returns -> bool`"
    assert_includes doc, "#### `returns_proc -> Proc[(Integer) -> bool]`"
    refute_includes doc, "#### `returns_proc(block:"
    assert_includes doc, "#### `arrows(Proc -> bool) -> bool`"
    assert_includes doc, "#### `spaced( String , Integer )`"
    assert_includes doc, "#### `trimmed_parts(name: String, count: Integer)`"
    refute_includes doc, "#### `trimmed_parts(name: String , count: Integer)`"
    assert_includes doc, "#### `merged(name: String, count: Integer) -> bool`"
    assert_includes doc, "#### `named(name: String, count: Integer) -> bool`"
    assert_includes doc, "#### `mismatch(String)`"
    assert_includes doc, "#### `bad_name(String)`"
    assert_includes doc, "#### `partial(name: name: String, count: Integer)`"
    assert_includes doc, "#### `keyword(flag: bool)`"
    assert_includes doc, "#### `bad_second(String, Integer)`"
    assert_includes doc, "#### `nested(items: Array[String], block: Proc[(Integer) -> bool]) -> value`"
    assert_includes doc, "#### `nested_first(wrapped: (String), count: Integer)`"
    refute_includes doc, "#### `nested_first((String), Integer)`"
    assert_includes doc, "#### `paren_comma(tuple: Tuple(String, Integer), value: Float)`"
    refute_includes doc, "#### `paren_comma(Tuple(String, Integer), Float)`"
    assert_includes doc, "#### `bracket_comma(items: Array[String, Integer], value: Float)`"
    refute_includes doc, "#### `bracket_comma(Array[String, Integer], Float)`"
    assert_includes doc, "#### `brace_comma(mapping: Hash{String, Integer}, value: Float)`"
    refute_includes doc, "#### `brace_comma(Hash{String, Integer}, Float)`"
    assert_includes doc, "#### `forms(*items: Array, **options: Hash, &block: Proc, keyword: bool)`"
    assert_includes doc, "#### `single(x: String)`"
    assert_includes doc, "#### `mentioned_splat(*items: Array)`"
    refute_includes doc, "#### `mentioned_splat(*items: *items: Array)`"
    assert_includes doc, "#### `named_splat(items: Array)`"
    refute_includes doc, "#### `named_splat(*items: items: Array)`"
    assert_includes doc, "#### `named_block(block: Proc)`"
    refute_includes doc, "#### `named_block(&block: block: Proc)`"
    assert_includes doc, "#### `nil_params(String)`"
    assert_includes doc, "#### `spaced_params(name: String, count: Integer, value: Float)`"
    assert_includes doc, "#### `open_only(String)`"
    assert_includes doc, "#### `close_only(String)`"
    refute_includes doc, "#### `open_only(name: String)`"
    refute_includes doc, "#### `close_only(name: String)`"
  end

  def test_method_signatures_use_rdoc_8_merged_type_signature_lines
    method = visible_method("typed", params: "(name)")
    method.define_singleton_method(:type_signature_lines) { ["(String) -> bool"] }

    doc = generated_class_doc([method])

    assert_includes doc, "_Type signatures available._"
    assert_includes doc, "#### `typed(name: String) -> bool`"
  end
end
