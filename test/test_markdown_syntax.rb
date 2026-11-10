# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"

class TestMarkdownSyntax < Minitest::Test
  cover "RDoc::Generator::Markdown::Syntax*"

  Syntax = RDoc::Generator::Markdown::Syntax

  def test_literal_text_escapes_every_markdown_metacharacter
    assert_equal '\\\\\\`\\*\\_\\[\\]\\<\\>\\#', Syntax.escape('\\`*_[]<>#')
    assert_equal "12\\. item", Syntax.escape("12. item")
    assert_equal "12.item", Syntax.escape("12.item")
    assert_equal "a 12. item", Syntax.escape("a 12. item")
    assert_equal "plain. text", Syntax.escape("plain. text")
  end

  def test_code_spans_choose_and_pad_their_delimiters
    assert_equal "`plain`", Syntax.code("plain")
    assert_equal "``a`b``", Syntax.code("a`b")
    assert_equal "```a``b```", Syntax.code("a``b")
    assert_equal "`` `start ``", Syntax.code("`start")
    assert_equal "`` end` ``", Syntax.code("end`")
    assert_equal "`` `both` ``", Syntax.code("`both`")
  end

  def test_fenced_code_is_literal_and_uses_the_explicit_language
    assert_equal "```ruby\n  <b>&lt;literal&gt;</b>\n```", Syntax.code_block("  <b>&lt;literal&gt;</b> \n", :ruby)
    assert_equal "````\n```\n````", Syntax.code_block("```", nil)
    assert_equal "`````text\n````\n`````", Syntax.code_block("````", "text")
  end

  def test_anchor_attributes_are_escaped_without_changing_the_identifier
    assert_equal '<a id="a&amp;&quot;&lt;&gt;&#39;"></a>', Syntax.anchor('a&"<>\'')
    assert_equal '<a id="plain"></a>', Syntax.anchor("plain")
  end

  def test_headings_cap_the_level_and_retain_alias_order
    assert_equal "## Topic<a id=\"first\"></a><a id=\"second\"></a>", Syntax.heading(2, "Topic", %w[first second])
    assert_equal "###### Deep", Syntax.heading(7, "Deep", [])
    assert_equal "# Plain", Syntax.heading(1, "Plain", [])
  end

  def test_list_items_indent_every_continuation_by_the_marker_width
    assert_equal "- first\n  second\n  \n  third", Syntax.item("-", "first\nsecond\n\nthird")
    assert_equal "10. first\n    second", Syntax.item("10.", "first\nsecond")
  end

  def test_targets_only_rewrite_local_document_extensions_and_legacy_prefixes
    {
      "www.example.test" => "https://www.example.test",
      "HTTPS://example.test/a.html" => "HTTPS://example.test/a.html",
      "mailto:a@example.test" => "mailto:a@example.test",
      "mailto:docs@example.test?subject=guide.html" => "mailto:docs@example.test?subject=guide.html",
      "http://example.test/a.html" => "http://example.test/a.html",
      "#a.html" => "#a.html",
      "Thing.HTML#part" => "Thing.md#part",
      "Thing.html?query" => "Thing.md?query",
      "Thing.htmlx" => "Thing.htmlx",
      "/Thing.md" => "Thing.md",
      "/Thing.md?query" => "Thing.md?query",
      "/Thing.md#part" => "Thing.md#part",
      "/Thing.txt" => "/Thing.txt",
      "../classes/Thing.html" => "../Thing.md",
      "../../modules/Thing.html?x#y" => "../../Thing.md?x#y",
      "files/guide.html" => "guide.md",
      "classes/Thing.txt" => "classes/Thing.txt",
      "folder/classes/Thing.md" => "folder/classes/Thing.md"
    }.each { |input, expected| assert_equal expected, Syntax.target(input), input }
  end

  def test_links_recover_only_ruby_receiver_indexing_expressions
    assert_equal "`Thing[:key]`", Syntax.link("Thing", ":key")
    assert_equal '`A::Thing["key"]`', Syntax.link("A::Thing", '"key"')
    assert_equal "`A::B[:key]`", Syntax.link("A::B", ":key")
    assert_equal "`a[:key]`", Syntax.link("a", ":key")
    assert_equal "`_[:key]`", Syntax.link("_", ":key")
    assert_equal "`thing_name[:key]`", Syntax.link('thing\\_name', ":key")
    assert_equal "[Label](Thing.md)", Syntax.link("Label", "Thing.html")
    assert_equal "[two words](:key)", Syntax.link("two words", ":key")
    assert_equal "[Thing](:)", Syntax.link("Thing", ":")
    assert_equal "[Thing](\"\")", Syntax.link("Thing", '""')
    assert_equal "[1Thing](:key)", Syntax.link("1Thing", ":key")
    assert_equal "[Thing!](:key)", Syntax.link("Thing!", ":key")
  end
end
