# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"

class TestInlineHtml < Minitest::Test
  cover "RDoc::Generator::Markdown::InlineHtml*"

  def render(markdown)
    RDoc::Generator::Markdown::InlineHtml.render(markdown)
  end

  def test_terms_have_no_paragraph_wrappers_and_keep_inline_formatting
    assert_equal "", render("")
    assert_equal "plain &amp; &lt;literal&gt;", render("plain & \\<literal\\>")
    assert_equal "<strong>bold</strong> <em>emphasis</em> <del>deleted</del> <code>&lt;code&gt;</code>",
      render("**bold** *emphasis* ~~deleted~~ `<code>`")
    assert_equal "# Title 1. term", render('\\# Title 1\\. term')
  end

  def test_terms_preserve_native_anchors_and_breaks
    assert_equal '<a id="note"></a>label', render('<a id="note"></a>label')
    assert_equal "first\nsecond<br>\nthird", render("first\nsecond  \nthird")
  end

  def test_links_escape_destinations_and_optional_titles
    assert_equal '<a href="path?a=1&amp;b=2">label</a>', render("[label](path?a=1&b=2)")
    assert_equal '<a href="path" title="&quot;&amp;&lt;&gt;"><strong>label</strong></a>',
      render('[**label**](path "&quot;&amp;&lt;&gt;")')
  end

  def test_bare_email_addresses_are_not_automatically_linked_inside_html
    assert_equal "name@example.test", render("name@example.test")
  end

  def test_supported_non_utf8_inputs_are_transcoded_at_the_ast_boundary
    assert_equal "plain", render("plain".encode(Encoding::US_ASCII))
    assert_equal "café", render("café".encode(Encoding::ISO_8859_1))
  end

  def test_images_have_plain_alt_text_and_escaped_attributes
    assert_equal '<img src="image?a=1&amp;b=2" alt="a &amp; b &lt;c&gt;">',
      render("![a *& b* `<c>`](image?a=1&b=2)")
    assert_equal '<img src="image" alt="alt" title="&quot;&amp;&lt;&gt;">',
      render('![alt](image "&quot;&amp;&lt;&gt;")')
  end
end
