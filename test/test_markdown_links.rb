# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"
require "commonmarker"

class TestMarkdownLinks < Minitest::Test
  cover "RDoc::Generator::Markdown::MarkdownLinks*"
  cover "RDoc::Generator::Markdown::Inline*"

  def formatter
    page = rdoc_page(rdoc_store, relative_name: "guide.rdoc", comment: "")
    RDoc::Generator::Markdown::Formatter.new(page, output_object_ids: Set[page.object_id], heading_level_offset: 0)
  end

  def render(text)
    markdown = formatter.attributes(text)
    refute_includes markdown, "\0RDocMarkdown"
    Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))
  end

  def test_markdown_links_keep_labels_and_do_not_autolink_their_destinations
    assert_equal "See [RFC 6265](https://example.test/rfc#5.2).",
      formatter.attributes("See [RFC 6265](https://example.test/rfc#5.2).")
    html = render("[one](One.html) and [two](Two.html)")
    assert_equal ["one", "two"], html.css("a").map(&:text)
    assert_equal ["One.md", "Two.md"], html.css("a").map { |node| node["href"] }
  end

  def test_nested_labels_parentheses_titles_and_spaces_use_the_markdown_parser
    html = render('[outer [inner] and *bold* +code+](https://example.test/a_(b) "A title")')
    assert_equal "https://example.test/a_(b)", html.at_css("a")["href"]
    assert_equal "A title", html.at_css("a")["title"]
    assert_equal "outer [inner] and bold code", html.at_css("a").text
    assert_equal "bold", html.at_css("a strong").text
    assert_equal "code", html.at_css("a code").text
    spaced = render('[label](<folder/file name.html> "title")')
    assert_equal "folder/file%20name.md", spaced.at_css("a")["href"]
  end

  def test_unicode_multiline_and_non_utf8_source_positions_preserve_surrounding_text
    assert_equal "é\n[Å](Thing.md)\n尾", formatter.attributes("é\n[Å](Thing.html)\n尾")
    assert_equal "café [lien](Thing.md)", formatter.attributes("café [lien](Thing.html)".encode(Encoding::ISO_8859_1))
    html = render("before [two\nlines](Thing.html) after")
    assert_equal "before two lines after", html.text.gsub(/\s+/, " ").strip
    assert_equal "Thing.md", html.at_css("a")["href"]
    assert_equal "Thing.md", render("[label](Thing.html)z").at_css("a")["href"]
  end

  def test_empty_labels_and_escaped_brackets_are_preserved
    empty = render("[](Thing.html)")
    assert_equal "", empty.at_css("a").text
    assert_equal "Thing.md", empty.at_css("a")["href"]
    escaped = render('[a \] bracket](Thing.html)')
    assert_equal "a ] bracket", escaped.at_css("a").text
  end

  def test_literal_entities_and_empty_code_do_not_gain_visible_characters
    html = render("+&lt;+ &amp; &#65; <code></code> after")
    assert_equal "+&lt;+ &amp; &#65;  after", html.at_css("p").text
    assert_equal "", html.at_css("code").text
    assert_equal 1, html.css("code").length
  end

  def test_images_nested_in_links_are_not_registered_twice
    html = render('[![alt](image.png "image title")](Thing.html "link title") trailing text')
    assert_equal 1, html.css("a").length
    assert_equal 1, html.css("img").length
    assert_equal "Thing.md", html.at_css("a")["href"]
    assert_equal "link title", html.at_css("a")["title"]
    assert_equal "image.png", html.at_css("a img")["src"]
    assert_equal "alt", html.at_css("a img")["alt"]
    assert_equal "image title", html.at_css("a img")["title"]
    assert_equal " trailing text", html.at_css("p").text
    assert_equal "image.png", render("word![alt](image.png)").at_css("img")["src"]
  end

  def test_markdown_links_in_a_native_link_label_cannot_nest_links
    html = render("{[inner](https://inner.test) ![alt](image.png)}[https://outer.test]")
    assert_equal ["https://outer.test"], html.css("a").map { |node| node["href"] }
    assert_equal "inner ", html.at_css("a").text
    assert_equal "image.png", html.at_css("a img")["src"]
  end

  def test_native_code_tags_keep_markdown_link_examples_literal
    ["code", "tt"].each do |tag|
      html = render("<#{tag}>[literal](Thing.html)</#{tag}> [actual](Thing.html)")
      assert_equal "[literal](Thing.html)", html.at_css("code").text
      assert_equal ["Thing.md"], html.css("a").map { |node| node["href"] }
    end
    escaped = render('<code>x \</code> [inside](Inside.html)</code> [outside](Outside.html)')
    assert_includes escaped.at_css("code").text, "[inside](Inside.html)"
    assert_equal ["Outside.md"], escaped.css("a").map { |node| node["href"] }
    mismatched = render("<tt>[literal](Thing.html)</code> [actual](Thing.html)")
    assert_empty mismatched.css("code")
    assert_equal ["literal", "actual"], mismatched.css("a").map(&:text)
    assert_equal ["Thing.md", "Thing.md"], mismatched.css("a").map { |node| node["href"] }
    adjacent = render("[before](Before.html)<code>[literal](Thing.html)</code>[after](After.html)")
    assert_equal ["Before.md", "After.md"], adjacent.css("a").map { |node| node["href"] }
    empty = render("<code></code>[actual](Actual.html)<code>[literal](Thing.html)</code>")
    assert_equal ["Actual.md"], empty.css("a").map { |node| node["href"] }
    unicode = render("日本語" * 20 + "<code>[literal](Thing.html)</code> [actual](Actual.html)")
    assert_equal "[literal](Thing.html)", unicode.at_css("code").text
    assert_equal ["Actual.md"], unicode.css("a").map { |node| node["href"] }
  end

  def test_escaped_and_unclosed_code_tags_do_not_hide_markdown_links
    escaped = render('\<code>[label](Thing.html)</code>')
    assert_empty escaped.css("code")
    assert_equal "Thing.md", escaped.at_css("a")["href"]
    unclosed = render("<code>[label](Thing.html)")
    assert_empty unclosed.css("code")
    assert_equal "Thing.md", unclosed.at_css("a")["href"]
  end

  def test_native_indexing_and_tidylinks_take_priority_over_markdown_links
    assert_equal "`Thing[:key]`(arg)", formatter.attributes("Thing[:key](arg)")
    assert_equal "[native](target)(tail)", formatter.attributes("{native}[target](tail)")
    assert_equal "[example.test](https://example.test) [link](Thing.md)",
      formatter.attributes("https://example.test [link](Thing.html)")
  end

  def test_literal_token_like_input_is_not_confused_with_registered_links
    text = "\0RDocMarkdown0\0 \0RDocMarkdownX0\0 [real](Thing.html)"
    assert_equal "\0RDocMarkdown0\0 \0RDocMarkdownX0\0 [real](Thing.md)", formatter.attributes(text)
    assert_equal "\0RDocMarkdown999\0", formatter.handle_regexp_markdown("\0RDocMarkdown999\0")
  end

  def test_more_than_ten_links_keep_every_registered_token
    text = (0..10).map { |index| "[label#{index}](Thing#{index}.html)" }.join(" ")
    assert_equal (0..10).map { |index| "Thing#{index}.md" }, render(text).css("a").map { |node| node["href"] }
  end

  def test_source_without_markdown_links_keeps_its_encoding
    text = "café".encode(Encoding::ISO_8859_1)
    assert_equal text, RDoc::Generator::Markdown::MarkdownLinks.new(text).source
    assert_equal Encoding::ISO_8859_1, RDoc::Generator::Markdown::MarkdownLinks.new(text).source.encoding
  end

  def test_links_after_multiple_unicode_lines_use_accumulated_byte_offsets
    assert_equal "é\n日本語\n[Å](Thing.md)\n尾", formatter.attributes("é\n日本語\n[Å](Thing.html)\n尾")
  end
end
