# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"

class TestMarkdownHtmlInput < Minitest::Test
  cover "RDoc::Generator::Markdown::HtmlInput*"

  def render(html, offset: 0)
    RDoc::Generator::Markdown::HtmlInput.new(heading_level_offset: offset).render(html)
  end

  def test_text_and_inline_elements_are_rendered_without_losing_literal_text
    assert_equal "plain \\*text\\* tail", render("plain *text* tail")
    assert_equal "first second third", render("first\nsecond\nthird")
    assert_equal "before **bold** *italic* ~~strike~~ after", render("<p>before <strong>bold</strong> <em>italic</em> <del>strike</del> after</p>")
    assert_equal "**b** *i* ~~s~~", render("<p><b>b</b> <i>i</i> <s>s</s></p>")
    assert_equal "`code` `tt`<br>text", render("<p><code>code</code> <tt>tt</tt><br>text</p>")
    assert_equal "transparent", render('<div><span id="ordinary">transparent</span></div>')
    assert_equal "transparent", render('<span href="Thing.html">transparent</span>')
  end

  def test_links_and_explicit_anchors_retain_their_distinct_roles
    assert_equal "[label](Thing.md)", render('<a href="Thing.html">label</a>')
    assert_equal "plain", render("<a>plain</a>")
    assert_equal '<a id="first"></a><a id="second"></a>', render('<a id="first" href="Thing.html">ignored</a><span class="legacy-anchor" id="second">ignored</span>')
    assert_equal "not an anchor", render('<span class="legacy-anchor">not an anchor</span>')
  end

  def test_paragraph_boundaries_do_not_depend_on_surrounding_blank_nodes
    assert_equal "first\n\nsecond", render("\n <p>first</p> \n<p>second</p>\n")
    assert_equal '<a id="a"></a>' + "\n\nparagraph", render('<span class="legacy-anchor" id="a"></span><p>paragraph</p>')
    assert_equal "# Heading\n\nparagraph", render("<h1>Heading</h1><p>paragraph</p>")
  end

  def test_unknown_html_is_preserved_and_only_actual_link_targets_are_rewritten
    assert_equal '<custom data-href="Thing.html"><a href="../Thing.md">one</a><a href="Other.md">two</a><a>three</a></custom>',
      render('<custom data-href="Thing.html"><a href="../classes/Thing.html">one</a><a href="Other.html">two</a><a>three</a></custom>')
  end

  def test_preformatted_code_keeps_indentation_and_language_metadata
    assert_equal "```ruby\n  return value\n```", render("<pre class=\"ruby\">\n  return value \n</pre>")
    assert_equal "```sql\nSELECT 1\n```", render('<pre class="brush: sql;">SELECT 1</pre>')
    assert_equal "```json\n{}\n```", render('<div class="highlight-json"><pre>{}</pre></div>')
    assert_equal "```\nx\n```", render('<pre class="highlight">x</pre>')
    assert_equal "```\nx\n```", render('<pre class="9invalid">x</pre>')
  end

  def test_heading_aliases_and_offsets_are_explicit
    assert_equal "#### Topic", render("<h2> Topic </h2>", offset: 2)
    assert_equal "## Topic<a id=\"old\"></a>", render('<h2>Topic<span class="legacy-anchor" id="old"></span></h2>')
    assert_equal "# Topic<a id=\"old\"></a>", render('<span class="legacy-anchor" id="old"></span><h1>Topic</h1>')
    assert_equal "# Topic", render('<span class="legacy-anchor" id="class-Topic"></span><h1>Topic</h1>')
    assert_equal "# Topic", render('<span class="legacy-anchor" id="module-Topic"></span><h1>Topic</h1>')
    assert_equal "# Topic<a id=\"notclass-Topic\"></a>", render('<span class="legacy-anchor" id="notclass-Topic"></span><h1>Topic</h1>')
    assert_equal '<a id="class-Topic"></a>' + "\n\nAfter", render('<span class="legacy-anchor" id="class-Topic"></span><p>After</p>')
    assert_equal '<a id="class-Topic"></a>', render('<span class="legacy-anchor" id="class-Topic"></span>')
  end

  def test_only_leading_nonempty_heading_self_links_are_flattened
    assert_equal "## Topic", render('<h2><a href="#topic">Topic</a></h2>')
    assert_equal "## Topic<a id=\"alias\"></a>", render('<h2> <a href="#alias">Topic</a></h2>')
    assert_equal "## Prefix [Topic](#alias)", render('<h2>Prefix <a href="#alias">Topic</a></h2>')
    assert_equal "## [Topic](https://example.test)", render('<h2><a href="https://example.test">Topic</a></h2>')
    assert_equal "## [](#)Topic", render('<h2><a href="#"></a>Topic</h2>')
    assert_equal "## [ ](#alias)Topic", render('<h2><a href="#alias"> </a>Topic</h2>')
    assert_equal "## Topic", render("<h2><a>Topic</a></h2>")
    assert_equal "## *Topic*", render("<h2><em>Topic</em></h2>")
  end
end
