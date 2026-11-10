# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"
require_relative "support/markdown_validator"

class TestMarkdownFormatter < Minitest::Test
  cover "RDoc::Generator::Markdown::Formatter*"
  cover "RDoc::Generator::Markdown::Blocks*"
  cover "RDoc::Generator::Markdown::Inline*"
  cover "RDoc::Generator::Markdown::References*"
  cover "RDoc::Generator::Markdown::Syntax*"
  cover "RDoc::Generator::Markdown::HtmlInput*"

  def test_automatic_urls_are_linked_without_the_rails_fixture
    page = rdoc_page(relative_name: "automatic-url.rdoc", comment: "https://example.test/a_b")

    assert_equal "[https://example.test/a\\_b](https://example.test/a_b)\n",
      read_generated("automatic-url_rdoc.md", pages: [page])
  end

  def test_method_descriptions_preserve_nested_source_and_destination_type_lists
    klass = rdoc_class("IO")
    method = rdoc_method("copy_stream", comment: <<~'RDOC')
      - The given +src+ must be one of the following:

        - The path to a readable file, from which source data is to be read.
        - An \IO-like object, opened for reading and capable of responding
          to method +:readpartial+ or method +:read+.

      - The given +dst+ must be one of the following:

        - The path to a writable file, to which data is to be written.
        - An \IO-like object, opened for writing and capable of responding
          to method +:write+.
    RDOC
    method.singleton = true
    klass.add_method(method)

    html = Nokogiri::HTML.fragment(Commonmarker.to_html(read_generated("IO.md", classes: [klass])))

    assert_equal 3, html.css("ul").length
    assert_equal 2, html.css("ul > li > ul").length
    assert_equal [
      "The path to a readable file, from which source data is to be read.",
      "An IO-like object, opened for reading and capable of responding to method :readpartial or method :read.",
      "The path to a writable file, to which data is to be written.",
      "An IO-like object, opened for writing and capable of responding to method :write."
    ], html.css("ul > li > ul > li").map { |node| node.text.strip }
  end

  def test_code_blocks_do_not_pass_through_the_html_formatter
    code = 'link_sanitizer.sanitize(\'<a href="example.com">Only the link text will be kept.</a>\')'
    page = rdoc_page(relative_name: "native-code.rdoc", comment: "= Example\n\n    #{code}\n")
    html_calls = []
    trace = TracePoint.new(:call) do |event|
      html_calls << event.method_id if RDoc::Markup::ToHtml === event.self
    end

    markdown = trace.enable { read_generated("native-code_rdoc.md", pages: [page]) }
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

    assert_empty html_calls
    assert_equal "#{code}\n", rendered.at_css("pre code").text
    assert_includes markdown, "```ruby\n#{code}\n```"
  end

  def test_code_blocks_preserve_explicit_languages_and_embedded_fences
    code = "```ruby\nputs :ok\n```\n````\n<b>&lt;literal&gt;</b>"
    verbatim = RDoc::Markup::Verbatim.new("#{code}\n")
    verbatim.format = :text
    page = rdoc_page(relative_name: "native-fences.rdoc", comment: "")
    page.comment = RDoc::Comment.from_document(RDoc::Markup::Document.new(verbatim))

    markdown = read_generated("native-fences_rdoc.md", pages: [page])
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

    assert_equal "`````text\n#{code}\n`````\n", markdown
    assert_equal "#{code}\n", rendered.at_css("pre code").text
  end

  def test_headings_keep_distinct_duplicate_anchor_ids
    page = rdoc_page(relative_name: "native-headings.rdoc", comment: "= Topic\n\n= Topic\n\n= Topic")

    assert_equal <<~MARKDOWN, read_generated("native-headings_rdoc.md", pages: [page])
      # Topic<a id="label-Topic"></a>
      # Topic<a id="label-Topic-1"></a><a id="topic-1"></a>
      # Topic<a id="label-Topic-2"></a><a id="topic-2"></a>
    MARKDOWN
  end

  def test_heading_self_links_do_not_duplicate_automatic_or_legacy_ids
    ["topic", "label-Topic"].each do |target|
      page = rdoc_page(relative_name: "self-link.rdoc", comment: "= {Topic}[##{target}]")

      assert_equal "# Topic<a id=\"label-Topic\"></a>\n", read_generated("self-link_rdoc.md", pages: [page])
    end
  end

  def test_code_blocks_honor_explicit_ruby_formats_even_for_invalid_ruby
    [:rb, :ruby].each do |format|
      verbatim = RDoc::Markup::Verbatim.new("not valid ruby <\n")
      verbatim.format = format
      page = rdoc_page(relative_name: "native-#{format}.rdoc", comment: "")
      page.comment = RDoc::Comment.from_document(RDoc::Markup::Document.new(verbatim))

      assert_equal "```ruby\nnot valid ruby <\n```\n", read_generated("native-#{format}_rdoc.md", pages: [page])
    end
  end

  def test_code_blocks_do_not_infer_ruby_over_explicit_languages
    {text: "puts :ok", json: '{"ok": true}', r: "1"}.each do |format, code|
      verbatim = RDoc::Markup::Verbatim.new("#{code}\n")
      verbatim.format = format
      page = rdoc_page(relative_name: "explicit-#{format}.rdoc", comment: "")
      page.comment = RDoc::Comment.from_document(RDoc::Markup::Document.new(verbatim))

      assert_equal "```#{format}\n#{code}\n```\n", read_generated("explicit-#{format}_rdoc.md", pages: [page])
    end
  end

  def test_raw_html_does_not_swallow_following_paragraphs
    document = RDoc::Markup::Document.new(
      RDoc::Markup::Raw.new("<dl><dt>Term</dt><dd>Definition</dd></dl>"),
      RDoc::Markup::Paragraph.new("Following paragraph.")
    )
    page = rdoc_page(relative_name: "native-html.rdoc", comment: "")
    page.comment = RDoc::Comment.from_document(document)
    markdown = read_generated("native-html_rdoc.md", pages: [page])
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

    assert_includes markdown, "</dl>\n\nFollowing paragraph."
    assert_equal "Following paragraph.", rendered.at_css("dl + p").text
  end

  def test_block_quotes_and_following_paragraphs
    page = rdoc_page(relative_name: "native-quote.rdoc", comment: "")
    page.comment.format = "markdown"
    page.comment.text = "> A quoted +value+.\n\nAfter the quotation."
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(read_generated("native-quote_rdoc.md", pages: [page])))

    assert_equal "A quoted +value+.", rendered.at_css("blockquote p").text
    assert_equal "After the quotation.", rendered.css("p").last.text
    assert_equal 1, rendered.css("blockquote").length
  end

  def test_single_column_tables_remain_tables
    page = rdoc_page(relative_name: "one-column.rdoc", comment: "")
    page.comment.format = "markdown"
    page.comment.text = "| Column |\n| --- |\n| Value |\n\nAfter."
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(read_generated("one-column_rdoc.md", pages: [page])))

    assert_equal ["Column"], rendered.css("th").map(&:text)
    assert_equal ["Value"], rendered.css("td").map(&:text)
    assert_equal "After.", rendered.at_css("table + p").text
  end

  def test_quoted_code_does_not_become_a_list
    page = rdoc_page(relative_name: "quoted-code.rdoc", comment: "")
    page.comment.format = "markdown"
    page.comment.text = "> ```text\n> * literal\n> ```"
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(read_generated("quoted-code_rdoc.md", pages: [page])))

    assert_equal "* literal\n", rendered.at_css("blockquote pre code").text
    assert_empty rendered.css("li")
  end

  def test_definition_terms_cannot_become_markdown_blocks
    list = RDoc::Markup::List.new(:LABEL,
      RDoc::Markup::ListItem.new("# Topic", RDoc::Markup::Paragraph.new("First.")),
      RDoc::Markup::ListItem.new("1. Term", RDoc::Markup::Paragraph.new("Second.")))
    page = rdoc_page(relative_name: "terms.rdoc", comment: "")
    page.comment = RDoc::Comment.from_document(RDoc::Markup::Document.new(list))
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(read_generated("terms_rdoc.md", pages: [page]), options: {render: {unsafe: true}}))

    assert_equal ["# Topic", "1. Term"], rendered.css("dt").map { |node| node.text.strip }
    assert_empty rendered.css("dt h1, dt ol")
  end

  def test_native_reference_options_and_inline_link_boundaries
    options = generator_options(op_dir: stable_tmpdir("references"))
    options.hyperlink_all = true
    options.show_hash = true
    options.autolink_excluded_words = ["Target"]
    store = RDoc::Store.new(options)
    target = rdoc_class("Target", comment: "Target docs. See #run and +Target+.", store: store)
    target.add_method(rdoc_method("run", comment: "Run."))
    source = rdoc_page(store, relative_name: "references.rdoc",
      comment: "Target {<code>Target</code>}[https://example.test] {https://label.test}[https://example.test] " \
        "rdoc-ref:Target {Image}[https://example.test/a.png] rdoc-image:https://example.test/b.png")
    store.classes_hash[target.full_name] = target
    store.complete(:public)
    RDoc::Generator::Markdown.new(store, options).generate
    markdown = File.read(File.join(options.op_dir, "references_rdoc.md"))
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

    assert markdown.start_with?("Target ")
    assert_equal ["https://example.test", "https://example.test", "Target.md"], html.css("a").map { |node| node["href"] }
    assert_equal "Target", html.at_css("a code").text
    assert_includes markdown, "![](https://example.test/a.png)"
    assert_includes markdown, "![](https://example.test/b.png)"
    assert_includes File.read(File.join(options.op_dir, "Target.md")), "[`#run`]"
    assert_same source, store.files_hash[source.relative_name]
  end

  def test_nil_exclusions_and_email_like_references_are_plain_text
    options = generator_options(op_dir: stable_tmpdir("email"))
    options.autolink_excluded_words = nil
    store = rdoc_store(options: options)
    rdoc_page(store, relative_name: "email.rdoc", comment: "Foo@example.test")
    store.complete(:public)
    RDoc::Generator::Markdown.new(store, options).generate

    assert_equal "Foo@example.test\n", File.read(File.join(options.op_dir, "email_rdoc.md"))
  end

  def test_reference_labels_cover_sections_methods_pages_and_local_headings
    klass = rdoc_class("Target", comment: "= Topic")
    klass.add_section("Details", RDoc::Comment.new("Details body."))
    klass.add_method(rdoc_method("run", comment: "= Inner"))
    klass.add_method(rdoc_method("+@", comment: "Plus."))
    guide = rdoc_page(relative_name: "guide.rdoc", comment: "= Heading")
    source = rdoc_page(relative_name: "references.rdoc", comment: "= Local\n\n" \
      "{Section}[rdoc-ref:Target@Details] {Topic}[rdoc-ref:Target@Topic] " \
      "{Inner}[rdoc-ref:Target#run@Inner] {Page}[rdoc-ref:guide@Heading] " \
      "{Local}[rdoc-ref:@Local] Target#+@")

    markdown = read_generated("references_rdoc.md", classes: [klass], pages: [source, guide])

    assert_includes markdown, "[Section](Target.md#details)"
    assert_includes markdown, "[Topic](Target.md#class-target-topic)"
    assert_includes markdown, "[Inner](Target.md#method-i-run-inner)"
    assert_includes markdown, "[Page](guide_rdoc.md#heading)"
    assert_includes markdown, "[Local](#local)"
    assert_includes markdown, "[`Target#+@`](Target.md#method-i-2B-40)"
  end

  def test_raw_inline_markup_and_backticks_use_native_primitives
    page = raw_html_page(relative_name: "inline.rdoc", html: '<p><a id="marker"></a><span>Text</span> ' \
      "<code>`tick`</code> <code>tail`</code> <b>bold</b> <i>emphasis</i><br>After</p>")
    markdown = read_generated("inline_rdoc.md", pages: [page])
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

    assert_equal ["`tick`", "tail`"], html.css("code").map(&:text)
    assert_equal "bold", html.at_css("strong").text
    assert_equal "emphasis", html.at_css("em").text
    assert_equal 1, html.css("br").length
    assert html.at_css('a[id="marker"]')
  end

  def test_paragraphs_preserve_rdoc_line_break_handling
    page = rdoc_page(relative_name: "native-paragraphs.rdoc", comment: "")
    page.comment.format = "markdown"
    page.comment.text = "first line\nsecond line\n\n日本語\nの文章\n\nhard line  \nbreak"

    markdown = read_generated("native-paragraphs_rdoc.md", pages: [page])

    assert_includes markdown, "first line second line"
    assert_includes markdown, "日本語の文章"
    assert_includes markdown, "hard line\n break"
  end

  def test_tables_do_not_swallow_following_paragraphs
    page = rdoc_page(relative_name: "native-table.rdoc", comment: "")
    page.comment.format = "markdown"
    page.comment.text = "| a | b |\n| --- | --- |\n| x | y |\n\nAfter the table."

    markdown = read_generated("native-table_rdoc.md", pages: [page])
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

    assert_equal ["a", "b"], rendered.css("th").map(&:text)
    assert_equal ["x", "y"], rendered.css("td").map(&:text)
    assert_equal "After the table.", rendered.at_css("table + p").text
  end

  def test_raw_code_keeps_meaningful_leading_indentation
    page = raw_html_page(relative_name: "indented.rdoc", html: "<pre>  * literal</pre>")
    html = Nokogiri::HTML.fragment(Commonmarker.to_html(read_generated("indented_rdoc.md", pages: [page])))

    assert_equal "  * literal\n", html.at_css("pre code").text
    assert_empty html.css("li")
  end
end
