# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"
require "commonmarker"

class TestMarkdownNativeCallbacks < Minitest::Test
  cover "RDoc::Generator::Markdown::Blocks*"
  cover "RDoc::Generator::Markdown::Inline*"
  cover "RDoc::Generator::Markdown::References*"
  cover "RDoc::Generator::Markdown::Formatter*"
  cover "RDoc::Generator::Markdown::Syntax*"

  def formatter(options: RDoc::Options.new, relative_name: "guide.rdoc")
    page = rdoc_page(rdoc_store(options: options), relative_name: relative_name, comment: "")
    RDoc::Generator::Markdown::Formatter.new(page, output_object_ids: Set[page.object_id], heading_level_offset: 2)
  end

  def test_paragraph_soft_breaks_are_normalized_throughout_the_paragraph
    visitor = formatter
    document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("one\nsecond\r\nthird\n\nfourth"))

    assert_equal "one second third fourth\n\n", document.accept(visitor)
    assert_equal "latin日本語\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("latin\n日本語")).accept(visitor)
    assert_equal "日本語latin\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("日本語\nlatin")).accept(visitor)
  end

  def test_only_standalone_linter_directive_lines_are_removed_from_prose
    {
      "Before.\nrubocop:disable Metrics/CyclomaticComplexity\nAfter." => "Before. After.\n\n",
      "standard:disable all\r\nKept." => "Kept.\n\n",
      "rubocop:enable" => "\n\n",
      "standard:enable\n" => "\n\n",
      "rubocop:todo Style/Documentation" => "\n\n",
      "rubocop:enabled is not a directive." => "rubocop:enabled is not a directive.\n\n",
      "Mention standard:disable in prose." => "Mention standard:disable in prose.\n\n"
    }.each do |text, expected|
      document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new(text))
      assert_equal expected, document.accept(formatter)
    end

    ["argument's value", "argument's value\nrubocop:disable all"].each do |text|
      document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new(text.encode(Encoding::US_ASCII)))
      assert_equal "argument's value\n\n", document.accept(formatter)
    end

    document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("<code>literal</code>", "rubocop:disable all"))
    assert_equal "`literal`\n\n", document.accept(formatter)
  end

  def test_linter_directives_inside_multiline_inline_code_are_not_removed
    %w[code tt].each do |tag|
      source = "rubocop:disable all\né 日本語 <#{tag}>\nrubocop:disable all\nstandard:enable all\n</#{tag}>\nrubocop:disable all"
      document = RDoc::Markup.parse(source)
      html = Nokogiri::HTML.fragment(Commonmarker.to_html(document.accept(formatter)))

      assert_equal "rubocop:disable all standard:enable all", html.at_css("code").text
      html.at_css("code").remove
      assert_equal "é 日本語", html.at_css("p").text.strip
      assert_equal 3, document.parts.first.text.scan("rubocop:disable all").length
    end

    source = "é `example\nrubocop:disable all\ncommand`\nstandard:enable all".encode(Encoding::ISO_8859_1)
    document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new(source))
    markdown = document.accept(formatter)
    assert_includes markdown, "rubocop:disable all"
    refute_includes markdown, "standard:enable all"
  end

  def test_class_subheadings_keep_legacy_aliases_even_when_the_title_does_not
    klass = rdoc_class("Sample", comment: "Docs.")
    visitor = RDoc::Generator::Markdown::Formatter.new(klass, output_object_ids: Set[klass.object_id], heading_level_offset: 2)
    document = RDoc::Markup::Document.new(RDoc::Markup::Heading.new(1, "Topic"), RDoc::Markup::Heading.new(2, "Subtopic"))

    assert_equal "### Topic<a id=\"class-sample-topic\"></a>\n\n#### Subtopic<a id=\"class-Sample-label-Subtopic\"></a><a id=\"class-sample-subtopic\"></a>\n\n",
      document.accept(visitor)
  end

  def test_markdown_style_paragraph_headings_keep_main_rendering_without_offsets
    visitor = formatter
    ["## Topic", "   ## Topic", "##   Topic", "##\t Topic"].each do |text|
      document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new(text))
      assert_equal "## Topic\n\n", document.accept(visitor)
    end
    assert_equal "## **Bold** `code`\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("## *Bold* +code+")).accept(visitor)
    assert_equal "# Topic words `code  span`\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("# Topic   words <code>code  span</code>")).accept(visitor)
    assert_equal "# \n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("#")).accept(visitor)
    assert_equal "###### Deep\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("###### Deep")).accept(visitor)
    assert_equal "\\#\\#\\#\\#\\#\\#\\# Literal\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("####### Literal")).accept(visitor)
    assert_equal "\\#NoSpace\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("#NoSpace")).accept(visitor)
    code = RDoc::Markup::Verbatim.new("## Not a heading\n")
    code.format = :text
    assert_equal "```text\n## Not a heading\n```\n\n", RDoc::Markup::Document.new(code).accept(visitor)
  end

  def test_heading_aliases_match_main_when_the_first_word_is_a_reference
    store = rdoc_store
    file = rdoc_file(store)
    target = file.add_class(RDoc::NormalClass, "Target")
    klass = file.add_class(RDoc::NormalClass, "Sample")
    store.complete(:public)
    visitor = RDoc::Generator::Markdown::Formatter.new(klass, output_object_ids: Set[klass.object_id, target.object_id], heading_level_offset: 0)
    document = RDoc::Markup::Document.new(
      RDoc::Markup::Heading.new(2, "Target Topic"),
      RDoc::Markup::Heading.new(2, "Before Target"),
      RDoc::Markup::Heading.new(2, "+Target+ code"),
      RDoc::Markup::Heading.new(2, "[plain]"),
      RDoc::Markup::Heading.new(2, "{Topic}[#other]"),
      RDoc::Markup::Heading.new(2, "[Topic](#other)"),
      RDoc::Markup::Heading.new(2, "")
    )

    assert_equal "## [`Target`](Target.md) Topic<a id=\"class-Sample-label-Target+Topic\"></a>\n\n" \
      "## Before [`Target`](Target.md)<a id=\"class-Sample-label-Before+Target\"></a><a id=\"class-sample-before-target\"></a>\n\n" \
      "## [`Target`](Target.md) code<a id=\"class-Sample-label-Target+code\"></a>\n\n" \
      "## \\[plain\\]<a id=\"class-Sample-label-5Bplain-5D\"></a><a id=\"class-sample-plain\"></a>\n\n" \
      "## Topic<a id=\"class-Sample-label-Topic\"></a><a id=\"other\"></a>\n\n" \
      "## [Topic](#other)<a id=\"class-Sample-label-5BTopic-5D-28-23other-29\"></a><a id=\"class-sample-topicother\"></a>\n\n" \
      "## <a id=\"class-Sample-label-\"></a>\n\n", document.accept(visitor)
  end

  def test_page_heading_aliases_survive_smart_punctuation_in_the_visible_title
    document = RDoc::Markup::Document.new(RDoc::Markup::Heading.new(1, "RAKE -- Ruby Make"))
    assert_equal "### RAKE – Ruby Make<a id=\"label-RAKE+--+Ruby+Make\"></a><a id=\"rake----ruby-make\"></a>\n\n",
      document.accept(formatter)
  end

  def test_heading_aliases_accept_non_utf8_source_text
    text = "café".encode(Encoding::ISO_8859_1)
    document = RDoc::Markup::Document.new(RDoc::Markup::Heading.new(1, text))
    markdown = document.accept(formatter)

    assert markdown.valid_encoding?
    assert_includes markdown.encode(Encoding::UTF_8), "### café"
  end

  def test_raw_blocks_join_all_parts_and_keep_the_following_paragraph_separate
    visitor = formatter
    document = RDoc::Markup::Document.new(
      RDoc::Markup::Raw.new("<h1>Topic</h1>", "<p>Body", "text</p>"), RDoc::Markup::Paragraph.new("After.")
    )

    assert_equal "### Topic\n\nBody text\n\nAfter.\n\n", document.accept(visitor)
  end

  def test_definition_bodies_keep_native_html_list_boundaries_and_inherited_code_mode
    {BULLET: ["ul", nil], NUMBER: ["ol", nil], LALPHA: ["ol", "list-style-type: lower-alpha"], UALPHA: ["ol", "list-style-type: upper-alpha"]}.each do |type, (tag, style)|
      code = RDoc::Markup::Verbatim.new("puts :ok\n")
      nested = RDoc::Markup::List.new(type, RDoc::Markup::ListItem.new(nil,
        RDoc::Markup::Paragraph.new("Nested."), RDoc::Markup::BlockQuote.new(code)))
      list = RDoc::Markup::List.new(:LABEL, RDoc::Markup::ListItem.new("Term", nested, RDoc::Markup::Paragraph.new("After nested list.")))
      markdown = RDoc::Markup::Document.new(list).accept(formatter)
      html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

      assert_equal "Nested.", html.at_css("dd #{tag} > li > p").text
      assert_equal style, html.at_css("dd #{tag}")["style"]
      assert_equal 1, html.css("dd #{tag}").length
      assert_equal "After nested list.", html.at_css("dd > p").text
      assert_equal "puts :ok\n", html.at_css("dd blockquote pre").text
      assert_equal "brush: ruby;", html.at_css("dd blockquote pre")["class"]
      assert_empty html.css("dd pre code")
      assert_includes markdown, "</li>\n\n</#{tag}>"
    end
  end

  def test_definition_bodies_preserve_unclassified_code_and_reject_invalid_nested_lists
    code = RDoc::Markup::Verbatim.new("<b>literal &amp; text</b>\n")
    list = RDoc::Markup::List.new(:LABEL, RDoc::Markup::ListItem.new("Term", code))
    markdown = RDoc::Markup::Document.new(list).accept(formatter)
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

    assert_equal code.text.rstrip, html.at_css("dd pre").text
    assert_nil html.at_css("dd pre")["class"]
    assert_empty html.css("dd pre b")
    code.format = 'text" onmouseover="bad&'
    markdown = RDoc::Markup::Document.new(list).accept(formatter)
    pre = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}})).at_css("pre")
    assert_equal 'brush: text" onmouseover="bad&;', pre["class"]
    assert_equal ["class"], pre.attributes.keys
    invalid = RDoc::Markup::List.new(:INVALID, RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("bad")))
    list = RDoc::Markup::List.new(:LABEL, RDoc::Markup::ListItem.new("Term", invalid))
    error = assert_raises(RDoc::Error) { RDoc::Markup::Document.new(list).accept(formatter) }
    assert_equal "Invalid list type: :INVALID", error.message
  end

  def test_definition_list_examples_do_not_replace_explicit_code_or_definition_body_code
    code = RDoc::Markup::Verbatim.new("bird::\n\n  * speak\n")
    code.format = :text

    assert_equal "```text\nbird::\n\n  * speak\n```\n\n", RDoc::Markup::Document.new(code).accept(formatter)

    code.format = nil
    list = RDoc::Markup::List.new(:LABEL, RDoc::Markup::ListItem.new("Example", code))
    markdown = RDoc::Markup::Document.new(list).accept(formatter)
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

    assert_equal "bird::\n\n  * speak\n", html.at_css("dd pre").text
    assert_empty html.css("dd li")
  end

  def test_non_definition_code_blocks_remain_literal
    {
      "" => "```ruby\n\n```\n\n",
      "* speak\n* fly\n" => "```\n* speak\n* fly\n```\n\n",
      "bird::\nwaterfowl::\n" => "```\nbird::\nwaterfowl::\n```\n\n",
      "bird::\n* speak\nplain text\n" => "```ruby\nbird::\n* speak\nplain text\n```\n\n"
    }.each do |text, expected|
      document = RDoc::Markup::Document.new(RDoc::Markup::Verbatim.new(text))
      assert_equal expected, document.accept(formatter)
    end
  end

  def test_nested_definition_lists_keep_their_terms_and_descriptions
    [:LABEL, :NOTE].each do |type|
      inner = RDoc::Markup::List.new(type, RDoc::Markup::ListItem.new("Inner", RDoc::Markup::Paragraph.new("Inner body.")))
      outer = RDoc::Markup::List.new(:NOTE, RDoc::Markup::ListItem.new("Outer", inner))
      markdown = RDoc::Markup::Document.new(outer).accept(formatter)
      html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

      assert_equal ["Outer", "Inner"], html.css("dt").map(&:text)
      assert_equal "Inner body.", html.at_css("dd dl dd p").text
      assert_equal "rdoc-list #{type.to_s.downcase}-list", html.at_css("dd dl")["class"]
      assert_empty html.css("dd dl li")
    end
  end

  def test_html_lists_are_separated_from_following_markdown_blocks_in_definitions
    nested = RDoc::Markup::List.new(:BULLET, RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Nested.")))
    quote = RDoc::Markup::BlockQuote.new(RDoc::Markup::Paragraph.new("Quoted tail."))
    list = RDoc::Markup::List.new(:LABEL, RDoc::Markup::ListItem.new("Term", nested, quote, RDoc::Markup::Heading.new(2, "After")))
    markdown = RDoc::Markup::Document.new(list).accept(formatter)
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

    assert_equal "Quoted tail.", html.at_css("dd > blockquote > p").text
    assert_equal "After", html.at_css("dd > h4").text
    assert_equal 1, html.css("dd > ul").length
  end

  def test_definition_lists_never_call_an_html_renderer
    list = RDoc::Markup::List.new(:NOTE, RDoc::Markup::ListItem.new("*Term* [link](Thing.html)",
      RDoc::Markup::Paragraph.new("Body."), RDoc::Markup::Verbatim.new("puts :ok\n")))
    html_calls = []
    trace = TracePoint.new(:call, :c_call) do |event|
      html_calls << event.method_id if RDoc::Markup::ToHtml === event.self ||
        (event.method_id == :to_html && (Commonmarker::Node === event.self || event.self == Commonmarker))
    end
    markdown = trace.enable { RDoc::Markup::Document.new(list).accept(formatter) }

    assert_empty html_calls
    assert_includes markdown, '<dt><strong>Term</strong> <a href="Thing.md">link</a></dt>'
    assert_includes markdown, '<dl class="rdoc-list note-list">'
  end

  def test_definition_paragraphs_do_not_become_markdown_headings_or_email_autolinks
    list = RDoc::Markup::List.new(:LABEL, RDoc::Markup::ListItem.new("Contact",
      RDoc::Markup::Paragraph.new("# Heading name@example.test *bold*")))
    markdown = RDoc::Markup::Document.new(list).accept(formatter)
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

    assert_empty html.css("h1, a")
    assert_equal "# Heading name@example.test bold", html.at_css("dd > p").text
    assert_equal "bold", html.at_css("dd > p > strong").text
  end

  def test_tables_render_inline_markup_and_escape_every_pipe_in_every_cell
    visitor = formatter
    visitor.start_accepting
    visitor.accept_table(["*Head*", "a|b|c"], [["<code>x|y</code>", "_em_"]], [nil, nil])

    assert_equal "| **Head** | a\\|b\\|c |\n| --- | --- |\n| `x\\|y` | *em* |\n\n", visitor.end_accepting
  end

  def test_native_lists_keep_main_paragraph_spacing
    visitor = formatter
    document = RDoc::Markup::Document.new(RDoc::Markup::List.new(:NUMBER,
      RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("First.")),
      RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Second."))))

    assert_equal "1. First.\n\n2. Second.\n\n", document.accept(visitor)
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(document.accept(visitor)))
    assert_equal ["First.", "Second."], html.css("ol > li > p").map(&:text)
  end

  def test_prose_keeps_main_typography_without_changing_code_or_urls
    visitor = formatter

    assert_equal "“Quoted `code`” and ‘single’ – — … .… © ® Mary’s word.",
      visitor.attributes(%q{"Quoted +code+" and 'single' -- --- ... .... (c) (r) Mary's word.})
    assert_equal "`\"quoted\" -- ... (c)`", visitor.attributes('<code>"quoted" -- ... (c)</code>')
    assert_equal "“[link](https://example.test/a--b)”", visitor.attributes('"{link}[https://example.test/a--b]"')
    assert_equal "“new paragraph”", visitor.attributes('"new paragraph"')
    assert_equal "“standalone label”", formatter.inline_nodes(['"standalone label"'])
    assert_equal "a\\`b", visitor.attributes("a`b")
    assert_equal "‘a \\`b’", visitor.attributes("'a `b'")
    assert_equal "(c)".encode(Encoding::ISO_8859_5), visitor.handle_regexp_HTML_CHARACTERS("(c)".encode(Encoding::ISO_8859_5))
  end

  def test_urls_preserve_their_scheme_and_map_source_extensions
    visitor = formatter

    assert_equal "[Guide](guide_rdoc.md#topic)", visitor.gen_url("link:guide.rdoc#topic", "Guide")
    assert_equal "[Source](source_rb.md?raw)", visitor.gen_url("link:source.rb?raw", "Source")
    assert_equal "[External](https://example.test/guide.html)", visitor.gen_url("https://example.test/guide.html", "External")
    assert_equal "[Plain](plain.rb.txt)", visitor.gen_url("link:plain.rb.txt", "Plain")
    assert_equal "[WWW](https://www.example.test)", visitor.gen_url("www.example.test", "WWW")
    assert_equal "![](https://example.test/a.jpeg)", visitor.gen_url("https://example.test/a.jpeg", "Image")
    assert_equal "[Local](local.png)", visitor.gen_url("link:local.png", "Local")
    assert_equal "[Guide](../guide_rdoc.md)", formatter(relative_name: "nested/source.rdoc").gen_url("link:guide.rdoc", "Guide")
    assert_equal "[Source](source_RB.md)", visitor.gen_url("link:source.RB", "Source")
    assert_equal "[Source](folder/a:file_rb.md)", visitor.gen_url("link:folder/a:file.rb", "Source")
    assert_equal "[Start](v1.2/getting_started_rdoc.md#top)", visitor.gen_url("link:v1.2/getting.started.rdoc#top", "Start")
    assert_equal "[Source](wwwXfile_rb.md)", visitor.gen_url("link:wwwXfile.rb", "Source")
    assert_equal "[Source](file_rb.md)", visitor.gen_url("link:/file.rb", "Source")
    assert_equal "[Source](1local:file_rb.md)", visitor.gen_url("link:1local:file.rb", "Source")
    %w[https://example.test/file.rb HTTP://example.test/file.rdoc //example.test/file.rb www.example.test/file.rb ftp://example.test/file.rb mailto:file.rb #file.rb x:file.rb a1:file.rb a+z:file.rb a-z:file.rb a.z:file.rb].each do |url|
      target = url.start_with?("www.") ? "https://#{url}" : url
      assert_equal "[Source](#{target})", visitor.gen_url(url, "Source")
    end
    %w[png gif jpg jpeg bmp].each do |extension|
      assert_equal "![](http://example.test/image.#{extension})", visitor.gen_url("http://example.test/image.#{extension}", "Image")
    end
  end

  def test_rdoc_labels_keep_both_the_target_and_the_explicit_source_anchor
    visitor = formatter

    assert_equal '<a id="marker"></a>[Note](#target)', visitor.gen_url("rdoc-label:target:marker", "Note")
    assert_equal "[Note](#target)", visitor.gen_url("rdoc-label:target", "Note")
    assert_equal '<a id="marker&quot;&amp;"></a>[Note](#target)', visitor.gen_url('rdoc-label:target:marker"&', "Note")
    assert_equal '<a id="scope:marker"></a>[Note](#target)', visitor.gen_url("rdoc-label:target:scope:marker", "Note")
    assert_equal '<sup><a id="footmark-12" href="#foottext-12">12</a></sup>',
      visitor.attributes("{^12}[rdoc-label:foottext-12:footmark-12]")
    assert_equal '<sup><a id="foottext-12" href="#footmark-12">12</a></sup>',
      visitor.attributes("{*12}[rdoc-label:footmark-12:foottext-12]")
    assert_equal '<sup><a id="footmarker" href="#target">Note</a></sup>', visitor.gen_url("rdoc-label:target:footmarker", "Note")
    rich_note = visitor.attributes("{*Bold*}[rdoc-label:target:footnote]")
    assert_equal "Bold", Nokogiri::HTML.fragment(Commonmarker.to_html(rich_note, options: {render: {unsafe: true}})).at_css("sup a strong").text
    assert_equal '[\\*note](#target)', visitor.attributes("{*note}[rdoc-label:target]")
    assert_equal "[prefix ^12](#target)", visitor.attributes("{prefix ^12}[rdoc-label:target]")
    assert_equal "[^12 suffix](#target)", visitor.attributes("{^12 suffix}[rdoc-label:target]")
    assert_equal "[12](https://example.test)", visitor.attributes("{^12}[https://example.test]")
    assert_equal "[**12**](#target)", visitor.attributes("{*12*}[rdoc-label:target]")
    assert_equal "[^12**bold**](#target)", visitor.attributes("{^12<b>bold</b>}[rdoc-label:target]")
    assert_equal '<sup><a id="footmark&quot;&amp;" href="#target&quot;&amp;">1</a></sup>',
      visitor.gen_url('rdoc-label:target"&:footmark"&', "1")
  end

  def test_explicit_link_labels_keep_their_ruby_namespace_prefix
    visitor = formatter

    assert_equal "[OpenSSL::SSL::SSLContext](OpenSSL::SSL::SSL::Context)",
      visitor.attributes("{OpenSSL::SSL::SSLContext}[OpenSSL::SSL::SSL::Context]")
    assert_equal "[https://label.test](https://target.test)",
      visitor.attributes("{https://label.test}[https://target.test]")
  end

  def test_link_label_boundaries_suppress_automatic_links_and_escape_visible_text
    visitor = formatter
    assert_false visitor.in_link_label?
    assert_equal "[example.test/a\\_b](https://example.test/a_b)", visitor.handle_regexp_HYPERLINK("https://example.test/a_b")
    assert_equal "Label", visitor.inline_nodes(["Label"])
    assert_equal "https://example.test/a\\_b", visitor.handle_regexp_HYPERLINK("https://example.test/a_b")
    assert_equal "Thing\\_Name", visitor.handle_regexp_CROSSREF("Thing_Name")
  end

  def test_automatic_url_registration_supports_each_scheme_and_stops_at_markup_boundaries
    visitor = formatter

    assert_equal "[example.test](http://example.test)", visitor.attributes("http://example.test")
    assert_equal "[a@example.test](mailto:a@example.test)", visitor.attributes("mailto:a@example.test")
    assert_equal "[www.example.test](https://www.example.test)", visitor.attributes("www.example.test")
    assert_equal "[guide.rdoc](guide_rdoc.md)", visitor.attributes("link:guide.rdoc")
    assert_equal "[example.test](https://example.test) done", visitor.attributes("https://example.test done")
    assert_equal "[example.test](https://example.test)\\<text\\>", visitor.attributes("https://example.test<text>")
    assert_equal "[example.test/file](ftp://example.test/file)", visitor.attributes("ftp://example.test/file")
    assert_equal "[example.test/room](irc://example.test/room)", visitor.attributes("irc://example.test/room")
  end

  def test_backslash_suppression_keeps_main_literal_escape_sequences
    visitor = formatter

    assert_equal '+\\\\n+, +\\\\r+, + plus; Source and method\\_name.',
      visitor.attributes('+\n+, +\r+, \+ plus; \Source and \method_name.')
    assert_equal '\\#run \\#Title ::run', visitor.attributes('\#run \#Title \::run')
  end

  def test_unresolved_explicit_references_retain_labels_and_only_warn_when_enabled
    options = RDoc::Options.new
    options.warn_missing_rdoc_ref = false
    visitor = formatter(options: options)

    assert_silent do
      assert_equal "Missing\\_Name", visitor.explicit_reference("Missing_Name")
      assert_equal "A label", visitor.explicit_reference("Missing_Name", "A label")
      assert_equal "Missing\\_Name", visitor.handle_regexp_RDOCLINK("rdoc-ref:Missing_Name")
    end
    options.warn_missing_rdoc_ref = true
    assert_output("guide_rdoc.html: `rdoc-ref:Missing_Name` can't be resolved for `A label`\n") do
      assert_equal "A label", visitor.explicit_reference("Missing_Name", "A label")
    end
  end
end
