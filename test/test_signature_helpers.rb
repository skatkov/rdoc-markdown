# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/rdoc"
require "rdoc/markdown"

class TestSignatureHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown::Signatures*"

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
    headings = method_headings(doc)

    assert_includes headings, "blank()"
    assert_includes headings, "nil_signature()"
    assert_includes headings, "nil_param_seq()"
    assert_includes headings, "empty_signature_named_params()"
    refute_includes headings, "empty_signature_named_params(name: )"
    assert_includes headings, "returns -> bool"
    assert_includes headings, "returns_proc -> Proc[(Integer) -> bool]"
    refute headings.any? { |heading| heading.start_with?("returns_proc(block:") }
    assert_includes headings, "arrows(Proc -> bool) -> bool"
    assert_includes headings, "spaced( String , Integer )"
    assert_includes headings, "trimmed_parts(name: String, count: Integer)"
    refute_includes headings, "trimmed_parts(name: String , count: Integer)"
    assert_includes headings, "merged(name: String, count: Integer) -> bool"
    assert_includes headings, "named(name: String, count: Integer) -> bool"
    assert_includes headings, "mismatch(String)"
    assert_includes headings, "bad_name(String)"
    assert_includes headings, "partial(name: name: String, count: Integer)"
    assert_includes headings, "keyword(flag: bool)"
    assert_includes headings, "bad_second(String, Integer)"
    assert_includes headings, "nested(items: Array[String], block: Proc[(Integer) -> bool]) -> value"
    assert_includes headings, "nested_first(wrapped: (String), count: Integer)"
    refute_includes headings, "nested_first((String), Integer)"
    assert_includes headings, "paren_comma(tuple: Tuple(String, Integer), value: Float)"
    refute_includes headings, "paren_comma(Tuple(String, Integer), Float)"
    assert_includes headings, "bracket_comma(items: Array[String, Integer], value: Float)"
    refute_includes headings, "bracket_comma(Array[String, Integer], Float)"
    assert_includes headings, "brace_comma(mapping: Hash{String, Integer}, value: Float)"
    refute_includes headings, "brace_comma(Hash{String, Integer}, Float)"
    assert_includes headings, "forms(*items: Array, **options: Hash, &block: Proc, keyword: bool)"
    assert_includes headings, "single(x: String)"
    assert_includes headings, "mentioned_splat(*items: Array)"
    refute_includes headings, "mentioned_splat(*items: *items: Array)"
    assert_includes headings, "named_splat(items: Array)"
    refute_includes headings, "named_splat(*items: items: Array)"
    assert_includes headings, "named_block(block: Proc)"
    refute_includes headings, "named_block(&block: block: Proc)"
    assert_includes headings, "nil_params(String)"
    assert_includes headings, "spaced_params(name: String, count: Integer, value: Float)"
    assert_includes headings, "open_only(String)"
    assert_includes headings, "close_only(String)"
    refute_includes headings, "open_only(name: String)"
    refute_includes headings, "close_only(name: String)"
  end

  def test_method_signatures_use_rdoc_8_merged_type_signature_lines
    method = visible_method("typed", params: "(name)")
    method.type_signature_lines = ["(String) -> bool"]

    doc = generated_class_doc([method])

    assert_includes method_headings(doc), "typed(name: String) -> bool"
  end
end
