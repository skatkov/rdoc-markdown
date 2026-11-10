# frozen_string_literal: true

require_relative "test_helper"

require "csv"
require "rdoc/rdoc"
require "rdoc/markdown"
require_relative "support/markdown_validator"

class TestMarkdownHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown#initialize"
  cover "RDoc::Generator::Markdown::References*"
  cover "RDoc::Generator::Markdown::Descriptions*"
  cover "RDoc::Generator::Markdown::Formatter*"
  cover "RDoc::Generator::Markdown::Blocks*"
  cover "RDoc::Generator::Markdown::Inline*"
  cover "RDoc::Generator::Markdown#debug"
  cover "RDoc::Generator::Markdown::Paths*"

  def rewrite_internal_links(markdown, known_output_paths, root_path_segment: "project")
    state = Struct.new(:root_path_segment, :known_output_paths).new(root_path_segment, known_output_paths)
    RDoc::Generator::Markdown::Paths.rewrite_internal_links(markdown, "docs/current.md", state)
  end

  def test_pages_are_markdownified_with_headings_links_and_definition_lists
    page = rdoc_page(
      relative_name: "guide.rdoc",
      comment: "= Heading\n\n{Guide}[guide.html] {Upper}[UPPER.HTML] {Mail}[mailto:test@example.com] {Anchor}[#topic]\n" \
               "{RootGuide}[/docs/root.html?x=1] {RootPlain}[/docs/plain.html] {RootText}[/docs/plain.txt] " \
               "{Secure}[https://example.com/page.html] {PlainHttp}[http://example.com/page.html] " \
               "{UpperSecure}[HTTPS://example.com/PAGE.HTML] " \
               "{MailHtml}[mailto:test.html] {AnchorHtml}[#topic.html]\n" \
               "{FilePath}[files/README.html] {ParentFile}[../files/README.html#top] " \
               "{ClassPath}[classes/Foo.html] {ParentClass}[../classes/Foo.html#top] " \
               "{ModulePath}[modules/Bar.html] {ParentModule}[../modules/Bar.html#top]\n\n" \
               "  bird::\n  * speak\n"
    )

    markdown = read_generated("guide_rdoc.md", pages: [page])

    assert_includes markdown, "# Heading"
    assert_includes markdown, "[Guide](guide.md)"
    assert_includes markdown, "[Mail](mailto:test@example.com)"
    assert_includes markdown, "[Anchor](#topic)"
    assert_includes markdown, "[Upper](UPPER.md)"
    assert_includes markdown, "[RootGuide](docs/root.md?x=1)"
    assert_includes markdown, "[RootPlain](docs/plain.md)"
    assert_includes markdown, "[RootText](/docs/plain.txt)"
    assert_includes markdown, "[Secure](https://example.com/page.html)"
    assert_includes markdown, "[PlainHttp](http://example.com/page.html)"
    assert_includes markdown, "[UpperSecure](HTTPS://example.com/PAGE.HTML)"
    assert_includes markdown, "[MailHtml](mailto:test.html)"
    assert_includes markdown, "[AnchorHtml](#topic.html)"
    assert_includes markdown, "[FilePath](README.md)"
    assert_includes markdown, "[ParentFile](../README.md#top)"
    assert_includes markdown, "[ClassPath](Foo.md)"
    assert_includes markdown, "[ParentClass](../Foo.md#top)"
    assert_includes markdown, "[ModulePath](Bar.md)"
    assert_includes markdown, "[ParentModule](../Bar.md#top)"
    assert_equal "bird::\n* speak\n", Nokogiri::HTML.fragment(Commonmarker.to_html(markdown)).at_css("pre code").text
    assert_equal "\n", markdown[-1]
  end

  def test_linked_headings_retain_rdoc_anchor_aliases
    page = rdoc_page(
      relative_name: "linked-heading-alias.rdoc",
      comment: "= {Topic}[#class-example-label-Topic]"
    )

    markdown = read_generated("linked-heading-alias_rdoc.md", pages: [page])

    assert_equal '# Topic<a id="label-Topic"></a><a id="class-example-label-Topic"></a>' + "\n", markdown
  end

  def test_internal_links_inside_code_are_left_alone
    markdown = "[a](docs/guide.md) `[b](docs/guide.md)` ``x`[c](docs/guide.md)`` \\` [d](docs/guide.md) \\`\n" \
      "```ruby\nrender(\"[e](docs/guide.md)\")\n```\n[f](docs/guide.md)"

    assert_equal "[a](guide.md) `[b](docs/guide.md)` ``x`[c](docs/guide.md)`` \\` [d](guide.md) \\`\n" \
      "```ruby\nrender(\"[e](docs/guide.md)\")\n```\n[f](guide.md)",
      rewrite_internal_links(markdown, Set["docs/guide.md"])
  end

  def test_markdown_examples_are_not_treated_as_generated_links
    page = raw_html_page(
      relative_name: "markdown-examples.rdoc",
      html: "<pre># [Topic](#topic)\n[Mime](:csv)\n[Site](www.example.com)\n" \
            "[Guide](guide.html)\n[Root](/docs/root.md)</pre>"
    )

    markdown = read_generated("markdown-examples_rdoc.md", pages: [page])

    assert_includes markdown, "```\n# [Topic](#topic)\n[Mime](:csv)\n[Site](www.example.com)\n" \
      "[Guide](guide.html)\n[Root](/docs/root.md)\n```"
  end

  def test_generator_applies_crossref_policy_only_while_rendering
    page = rdoc_page(relative_name: "guide.rdoc", comment: "Hidden")
    hidden = RDoc::NormalModule.new("Hidden")

    markdown = read_generated("guide_rdoc.md", classes: [hidden], pages: [page])

    assert_includes markdown, "`Hidden`"
    refute_includes markdown, "[`Hidden`]"
    assert_includes page.description, '<a href="Hidden.html"><code>Hidden</code></a>'
  end

  def test_section_descriptions_use_the_configured_locale
    locale = Object.new
    locale.define_singleton_method(:translate) do |text|
      {"Class body" => "Translated introduction", "Section body" => "Translated details"}.fetch(text, text)
    end
    options = generator_options(op_dir: stable_tmpdir("localized-sections"))
    options.locale = locale
    store = RDoc::Store.new(options)
    klass = rdoc_class("Localized", comment: "Class body", store: store)
    section_comment = RDoc::Comment.new("Section body")
    klass.add_section("Details", section_comment)
    store.classes_hash[klass.full_name] = klass
    store.complete(:public)

    RDoc::Generator::Markdown.new(store, options).generate
    markdown = File.read(File.join(options.op_dir, "Localized.md"))

    assert_includes markdown, "Translated introduction"
    assert_includes markdown, "Translated details"
    assert_equal "Section body", section_comment.text
  end

  def test_native_reopened_class_comments_keep_their_individual_markup_formats
    klass = rdoc_class("MixedMarkup", comment: "= RDoc heading")
    comment = RDoc::Comment.new("# Markdown heading\n\n[Link](https://example.test)\n\n[Reference][target]\n\n[target]: https://example.test/reference")
    comment.format = "markdown"
    klass.add_comment(comment, rdoc_file(klass.store, name: "extra.rb"))

    markdown = read_generated("MixedMarkup.md", classes: [klass])

    assert_includes markdown, "# RDoc heading"
    assert_includes markdown, "# Markdown heading"
    assert_includes markdown, "[Link](https://example.test)"
    assert_includes markdown, "[Reference](https://example.test/reference)"
    assert_equal 1, markdown.scan("# RDoc heading").length
    assert_equal 1, markdown.scan("# Markdown heading").length
  end

  def test_localized_markdown_sections_keep_their_markup_format
    source = "A [link](https://example.test)"
    translation = "Translated [link](https://example.test)"
    locale = Object.new
    locale.define_singleton_method(:translate) { |_text| translation }
    options = generator_options(op_dir: stable_tmpdir("localized-markdown-section"))
    options.locale = locale
    store = RDoc::Store.new(options)
    klass = rdoc_class("LocalizedMarkdown", store: store)
    comment = RDoc::Comment.new(source, klass.in_files.first)
    comment.format = "markdown"
    klass.add_section("Details", comment)
    store.classes_hash[klass.full_name] = klass
    store.complete(:public)

    RDoc::Generator::Markdown.new(store, options).generate
    markdown = File.read(File.join(options.op_dir, "LocalizedMarkdown.md"))

    assert_includes markdown, "## Details\n#{translation}\n"
    assert_equal source, comment.text
  end

  def test_localized_sections_preserve_document_backed_comments
    options = generator_options(op_dir: stable_tmpdir("localized-document-section"))
    options.locale = Object.new.tap { |locale| locale.define_singleton_method(:translate) { |text| text } }
    store = RDoc::Store.new(options)
    klass = rdoc_class("LocalizedDocument", store: store)
    document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("Section body"))
    klass.add_section("Details", RDoc::Comment.from_document(document))
    document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("More details"))
    klass.add_section("Details", RDoc::Comment.from_document(document))
    store.classes_hash[klass.full_name] = klass
    store.complete(:public)

    RDoc::Generator::Markdown.new(store, options).generate
    markdown = File.read(File.join(options.op_dir, "LocalizedDocument.md"))

    assert_includes markdown, "## Details\nSection body\n"
    assert_includes markdown, "More details"
  end

  def test_verbatim_pre_blocks_preserve_literal_html
    page = rdoc_page(relative_name: "pre-block.rdoc", comment: "= Heading\n\n    <b>bold</b>\n    a<br>b<BR/>c<br />d\n")

    markdown = read_generated("pre-block_rdoc.md", pages: [page])

    assert_includes markdown, "```\n<b>bold</b>\na<br>b<BR/>c<br />d\n```"
  end

  def test_rdoc_code_examples_preserve_erb_heredocs_and_literal_entities
    code = <<~RUBY.chomp
      require 'erb'
      template = <<~TEMPLATE
        <b><%= arg1 %> &lt;div&gt; &amp;</b>
      TEMPLATE
      erb = ERB.new(template)
    RUBY
    page = rdoc_page(
      relative_name: "erb-example.rdoc",
      comment: "= Example\n\n#{code.lines.map { |line| "    #{line}" }.join}\n"
    )

    markdown = read_generated("erb-example_rdoc.md", pages: [page])

    assert_includes markdown, "```ruby\n#{code}\n```"
  end

  def test_pre_blocks_remove_highlighting_without_reparsing_the_code
    page = raw_html_page(
      relative_name: "highlighted-template.rdoc",
      html: '<pre class="ruby"><span class="ruby-identifier">template</span> = ' \
            '<span class="ruby-string">\'&lt;b&gt;&lt;%= arg1 %&gt;&lt;/b&gt; &amp;lt;div&amp;gt; &amp;amp;\'</span></pre>'
    )

    markdown = read_generated("highlighted-template_rdoc.md", pages: [page])

    assert_equal "```ruby\ntemplate = '<b><%= arg1 %></b> &lt;div&gt; &amp;'\n```\n", markdown
  end

  def test_nested_lists_and_quotes_keep_code_out_of_html_conversion
    code = RDoc::Markup::Verbatim.new("<a href=\"example.com\">literal &amp; text</a>\n````\n")
    code.format = :text
    document = RDoc::Markup::Document.new(
      RDoc::Markup::Paragraph.new("Before."),
      RDoc::Markup::List.new(:BULLET,
        RDoc::Markup::ListItem.new(nil,
          RDoc::Markup::Paragraph.new("First item."),
          RDoc::Markup::List.new(:NUMBER,
            RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Nested item."), code)),
          RDoc::Markup::BlockQuote.new(RDoc::Markup::Paragraph.new("Quoted."), code)),
        RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Second item."))),
      RDoc::Markup::Paragraph.new("After.")
    )
    page = rdoc_page(relative_name: "native-containers.rdoc", comment: "")
    page.comment = RDoc::Comment.from_document(document)
    html_calls = []
    trace = TracePoint.new(:call) do |event|
      if [:accept_list_start, :accept_block_quote, :accept_verbatim].include?(event.method_id) && RDoc::Markup::ToHtml === event.self
        html_calls << event.method_id
      end
    end

    markdown = trace.enable { read_generated("native-containers_rdoc.md", pages: [page]) }
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

    assert_empty html_calls
    assert_equal 2, rendered.css("ul > li").length
    assert_equal code.text, rendered.at_css("ul ol pre code").text
    assert_equal code.text, rendered.at_css("ul blockquote pre code").text
    assert_equal "Before.", rendered.css("p").first.text
    assert_equal "After.", rendered.css("p").last.text
    assert_includes markdown, "- Second item."
  end

  def test_native_definition_lists_render_their_contents_as_markdown
    [:LABEL, :NOTE].each do |type|
      code = RDoc::Markup::Verbatim.new("<b>literal &amp; text</b>\n````\n")
      code.format = :text
      document = RDoc::Markup::Document.new(
        RDoc::Markup::Heading.new(2, "Before"),
        RDoc::Markup::List.new(type,
          RDoc::Markup::ListItem.new(["Term", "+code+"],
            RDoc::Markup::Paragraph.new("Description."), code,
            RDoc::Markup::List.new(:BULLET,
              RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Nested bullet.")))),
          RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Extra description."))),
        RDoc::Markup::Heading.new(2, "After")
      )
      page = rdoc_page(relative_name: "native-#{type}.rdoc", comment: "")
      page.comment = RDoc::Comment.from_document(document)

      dir = generate_markdown(pages: [page])
      markdown = File.read(File.join(dir, "native-#{type}_rdoc.md"))
      rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown, options: {render: {unsafe: true}}))

      assert_equal ["Term", "code"], rendered.css("dl > dt").map { |term| term.text.strip }
      assert_empty rendered.css("dt p")
      assert_equal "code", rendered.at_css("dt code").text
      assert_includes markdown, "<dt>Term</dt>\n<dt><code>code</code></dt>\n<dd>"
      assert_equal 2, rendered.css("dl > dd").length
      assert_equal code.text.rstrip, rendered.at_css("dd pre").text
      assert_equal "brush: text;", rendered.at_css("dd pre")["class"]
      assert_equal "Nested bullet.", rendered.at_css("dd ul li").text.strip
      assert_equal "Nested bullet.", rendered.at_css("dd ul li p").text
      assert_equal "Extra description.", rendered.css("dd").last.text.strip
      assert_equal ["Before", "After"], rendered.css("h2").map(&:text)
      assert_equal "rdoc-list #{type.to_s.downcase}-list", rendered.at_css("dl")["class"]
      assert_equal 1, MarkdownValidator.new(dir).validate!
    end
  end

  def test_native_ordered_lists_indent_code_after_double_digit_markers
    [:NUMBER, :LALPHA, :UALPHA].each do |type|
      items = (1..11).map do |number|
        RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Entry #{number}."))
      end
      items.last << RDoc::Markup::Verbatim.new("puts :ok\n")
      page = rdoc_page(relative_name: "ordered-#{type}.rdoc", comment: "")
      page.comment = RDoc::Comment.from_document(RDoc::Markup::Document.new(RDoc::Markup::List.new(type, *items)))

      markdown = read_generated("ordered-#{type}_rdoc.md", pages: [page])
      rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

      assert_equal 11, rendered.css("ol > li").length
      assert_equal "puts :ok\n", rendered.at_css("ol > li:last-child pre code").text
      assert_includes markdown, "1. Entry 1."
      assert_includes markdown, "11. Entry 11."
      assert_includes markdown, "\n    ```ruby\n    puts :ok\n    ```"
    end
  end

  def test_native_container_errors_restore_the_outer_output_buffer
    page = rdoc_page(rdoc_store, relative_name: "error.rdoc", comment: "")
    formatter = RDoc::Generator::Markdown::Formatter.new(page, output_object_ids: Set[page.object_id], heading_level_offset: 0)
    formatter.start_accepting
    RDoc::Markup::Paragraph.new("Before.").accept(formatter)
    quote = RDoc::Markup::BlockQuote.new(
      RDoc::Markup::Paragraph.new("Discarded."),
      RDoc::Markup::List.new(:INVALID)
    )

    error = assert_raises(RDoc::Error) { quote.accept(formatter) }
    assert_equal "Invalid list type: :INVALID", error.message
    RDoc::Markup::Paragraph.new("After.").accept(formatter)
    assert_equal "Before.\n\nAfter.\n\n", formatter.end_accepting
  end

  def test_only_top_level_context_legacy_anchors_are_dropped
    page = raw_html_page(
      relative_name: "context-legacy-anchors.rdoc",
      html: '<span id="module-example-label-Top" class="legacy-anchor"></span><h1>Top</h1>' \
            '<span id="class-example-label-Section" class="legacy-anchor"></span><h2>Section</h2>' \
            '<span id="module-example-label-Standalone" class="legacy-anchor"></span>'
    )

    assert_equal "# Top\n" \
                 "## Section<a id=\"class-example-label-Section\"></a>\n" \
                 "<a id=\"module-example-label-Standalone\"></a>\n",
      read_generated("context-legacy-anchors_rdoc.md", pages: [page])
  end

  def test_invalid_definition_list_blocks_remain_plain_text
    page = rdoc_page(relative_name: "invalid-definition.rdoc", comment: "= Heading\n\n  bird::\n  plain text\n")

    markdown = read_generated("invalid-definition_rdoc.md", pages: [page])

    assert_includes markdown, "```ruby\nbird::\nplain text\n```"
    refute_includes markdown, "- plain text"
  end

  def test_definition_list_blocks_preserve_blank_lines
    page = rdoc_page(
      relative_name: "spaced-definition.rdoc",
      comment: "= Heading\n\n  bird::\n\n    * speak\n    * fly\n\nBetween\n\n  waterfowl::\n\n    * swim\n"
    )

    markdown = read_generated("spaced-definition_rdoc.md", pages: [page])

    blocks = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown)).css("pre code").map(&:text)
    assert_equal 2, blocks.length
    assert_includes blocks.first, "bird::"
    assert_includes blocks.first, "* speak"
    assert_includes blocks.last, "waterfowl::"
    assert_includes blocks.last, "* swim"
  end

  def test_html_definition_list_lookalikes_remain_literal_code
    page = raw_html_page(
      relative_name: "html-definition-code.rdoc",
      html: "<pre>bird::\n* speak</pre>"
    )

    assert_equal "```\nbird::\n* speak\n```\n", read_generated("html-definition-code_rdoc.md", pages: [page])
  end

  def test_internal_links_are_rewritten_relative_to_generated_output
    guide = rdoc_page(
      relative_name: "guides/intro.rdoc",
      comment: "= {Intro}[#top]\n\n" \
               "== {Signing is not encryption}[#class-ActiveSupport::Messages::MessageVerifier-label-Signing+is+not+encryption]"
    )
    api = rdoc_page(relative_name: "guides/api.rdoc", comment: "= API")
    sibling = rdoc_page(relative_name: "docs/sibling.rdoc", comment: "= Sibling")
    simple_intro = rdoc_page(relative_name: "guides/simple.rdoc", comment: "Intro")
    single = rdoc_page(relative_name: "docs/single.rdoc", comment: "{Intro}[guides/intro_rdoc.html#top]")
    empty_anchor = rdoc_page(
      relative_name: "docs/empty-anchor.rdoc",
      comment: "{EmptyAnchor}[guides/simple_rdoc.html#] {RootIntro}[/guides/root-intro.md]"
    )
    readme = rdoc_page(
      relative_name: "docs/readme.rdoc",
      comment: "{Intro}[guides/intro_rdoc.html#top] {API}[guides/api_rdoc.html] " \
                 "{Missing}[missing/path.html#part] " \
                 "{Secure}[https://example.com/page.md#class-example-label-Topic] " \
                 "{Mail}[mailto:test@example.com] {Anchor}[#topic.md] " \
                  "{Sibling}[nested/../sibling_rdoc.html] " \
                 "{Legacy}[guides/intro_rdoc.html#class-ActiveSupport::Messages::MessageVerifier-label-Signing+is+not+encryption] " \
                 "{Query}[guides/intro_rdoc.html?tag=-label-test]"
    )

    dir = generate_markdown(pages: [guide, api, sibling, simple_intro, single, empty_anchor, readme])
    markdown = File.read(File.join(dir, "docs/readme_rdoc.md"))
    guide_markdown = File.read(File.join(dir, "guides/intro_rdoc.md"))

    assert_includes guide_markdown,
      '<a id="class-ActiveSupport::Messages::MessageVerifier-label-Signing+is+not+encryption"></a>'
    assert_includes markdown, "[Intro](../guides/intro_rdoc.md#top)"
    assert_includes markdown, "[API](../guides/api_rdoc.md)"
    assert_includes markdown, "[Missing](missing/path.md#part)"
    assert_includes markdown, "[Secure](https://example.com/page.md#class-example-label-Topic)"
    assert_includes markdown, "[Mail](mailto:test@example.com)"
    assert_includes markdown, "[Anchor](#topic.md)"
    assert_includes markdown, "[Sibling](sibling_rdoc.md)"
    assert_includes markdown,
      "[Legacy](../guides/intro_rdoc.md#class-ActiveSupport::Messages::MessageVerifier-label-Signing+is+not+encryption)"
    assert_includes markdown, "[Query](../guides/intro_rdoc.md?tag=-label-test)"
    assert_eql "[Intro](../guides/intro_rdoc.md#top)\n", File.read(File.join(dir, "docs/single_rdoc.md"))
    assert_eql "[EmptyAnchor](../guides/simple_rdoc.md#) [RootIntro](guides/root-intro.md)\n",
      File.read(File.join(dir, "docs/empty-anchor_rdoc.md"))
  end

  def test_internal_links_resolve_root_segment_candidates
    direct = rdoc_page(relative_name: "pages/guides/direct.rdoc", comment: "Direct")
    rooted = rdoc_page(relative_name: "pages/guides/rooted.rdoc", comment: "Rooted")
    nested = rdoc_page(relative_name: "pages/pages/guides/nested.rdoc", comment: "Nested")
    readme = rdoc_page(
      relative_name: "pages/docs/readme.rdoc",
      comment: "{Direct}[guides/direct_rdoc.html] {Rooted}[pages/guides/rooted_rdoc.html] " \
               "{Nested}[pages/guides/nested_rdoc.html]"
    )

    dir = generate_markdown(pages: [direct, rooted, nested, readme], root: "pages")

    assert_eql "[Direct](../guides/direct_rdoc.md) [Rooted](../guides/rooted_rdoc.md) " \
               "[Nested](../pages/guides/nested_rdoc.md)\n",
      File.read(File.join(dir, "docs/readme_rdoc.md"))
  end

  def test_internal_links_restore_local_array_paths_and_suffixes
    known_output_paths = ["guides/intro.md", "README.md", "GUIDE.markdown"]
    markdown = "[Relative](../guides/intro.md?view=full#topic) " \
      "[Root](project/guides/intro.md#root) [MD](README_md.md) [Markdown](GUIDE_markdown.md)"

    assert_equal "[Relative](../guides/intro.md?view=full#topic) " \
      "[Root](../guides/intro.md#root) [MD](../README.md) [Markdown](../GUIDE.markdown)",
      rewrite_internal_links(markdown, known_output_paths)
  end

  def test_internal_links_leave_empty_and_non_local_array_targets_unresolved
    targets = "[#](#topic) [?](?view=full) [HTTPS](HTTPS://example.test/guide.md) " \
      "[Mail](mailto:docs@example.test) [Short](x:guide.md) [Protocol](//example.test/guide.md)"
    known_output_paths = ["", "HTTPS://example.test/guide.md", "mailto:docs@example.test", "x:guide.md", "//example.test/guide.md"]

    assert_equal targets, rewrite_internal_links(targets, known_output_paths)
  end

  def test_internal_links_deduplicate_direct_array_candidates
    known_output_paths = ["target.md"]
    include_calls = 0
    trace = TracePoint.new(:c_call) do |event|
      include_calls += 1 if event.method_id == :include? && event.self.equal?(known_output_paths)
    end

    result = trace.enable { rewrite_internal_links("[Target](target_md.md)", known_output_paths) }

    assert_equal "[Target](../target.md)", result
    assert_equal 2, include_calls
  end

  def test_internal_links_expand_only_candidates_still_needed
    join_calls = 0
    trace = TracePoint.new(:call, :c_call) do |event|
      join_calls += 1 if event.method_id == :join && Pathname === event.self
    end

    direct = trace.enable { rewrite_internal_links("[Direct](target.md)", Set["target.md"]) }
    assert_equal "[Direct](../target.md)", direct
    assert_equal 0, join_calls

    expanded = trace.enable do
      rewrite_internal_links("[Expanded](project/target.md)", Set["docs/project/target.md"])
    end
    assert_equal "[Expanded](project/target.md)", expanded
    assert_equal 1, join_calls
  end

  def test_class_and_method_descriptions_are_markdownified
    klass = build_rdoc_class(full_name: "Docs::Thing", description: "= Class Topic")
    klass.add_section("Overview", RDoc::Comment.new("= Section Topic"))
    klass.add_constant(rdoc_constant("VALUE"))
    constructor = rdoc_method("new", visible: true, comment: "Creates a new entry using +str+.", signature: "(str)")
    constructor.singleton = true
    method = rdoc_method("run", visible: true, comment: "= Method Topic\n\n=== Method Detail\n\n==== Method Depth")
    klass.add_method(constructor)
    klass.add_method(method)
    klass.add_method(rdoc_method("plain", visible: true))
    class_formatter = klass.formatter

    markdown = read_generated("Docs/Thing.md", classes: [klass])

    assert_same klass, class_formatter.code_object
    assert_includes markdown, "# Class Docs::Thing"
    assert_includes markdown, "# Class Topic"
    refute_includes markdown, "## Class Topic"
    refute_includes markdown, "\n\n\n"
    assert_includes markdown,
      "# Class Topic<a id=\"class-docs-thing-class-topic\"></a>\n## Constants"
    refute_includes markdown, '<a id="class-Docs::Thing-label-Class+Topic"></a>'
    assert_includes markdown, "### `VALUE`<a id=\"VALUE\"></a>\nNot documented."
    assert_includes markdown, "## Overview"
    assert_includes markdown,
      "### Section Topic<a id=\"Overview-label-Section+Topic\"></a>" \
      "<a id=\"overview-section-topic\"></a>"
    refute_includes markdown, "\n# Section Topic\n"
    assert_includes markdown, "### `run()`"
    assert_includes markdown,
      "\n#### Method Topic<a id=\"method-i-run-label-Method+Topic\"></a>" \
      "<a id=\"method-i-run-method-topic\"></a>\n" \
      "###### Method Detail<a id=\"method-i-run-label-Method+Detail\"></a>" \
      "<a id=\"method-i-run-method-detail\"></a>\n"
    assert_includes markdown, "###### Method Depth"
    refute_match(/^<a id="[^"]+"><\/a>\n#+ /, markdown)
    refute_includes markdown, "\n###### Method Topic\n"
    refute_includes markdown, "\n####### Method Detail\n"
    refute_includes markdown, "\n####### Method Depth"
    refute_includes markdown, "\n## Method Detail\n"
    assert_includes markdown, "### `new(str)`<a id=\"method-c-new\"></a>\nCreates a new entry using `str`."
    refute_includes markdown, "### `new(str)`<a id=\"method-c-new\"></a>\n\nCreates"
    assert_includes markdown, "### `plain()`<a id=\"method-i-plain\"></a>\nNot documented."
    refute_includes markdown, "Alias for: [`plain`]"
  end

  def test_generate_keeps_methods_after_examples_following_definition_lists
    klass = build_rdoc_class(full_name: "Relation")
    klass.add_method(rdoc_method(
      "insert",
      comment: "[Returns]\n  The result.\n\n== Examples\n\n    value = 1\n\n    value += 1\n"
    ))
    klass.add_method(rdoc_method("load"))

    dir = generate_markdown(classes: [klass])
    markdown = File.read(File.join(dir, "Relation.md"))
    rendered = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))

    assert_includes markdown, "</dl>\n\n##### Examples"
    assert_includes rendered.css("h3").map(&:text), "load()"
    assert_eql "value = 1\n\nvalue += 1\n", rendered.at_css("pre code").text
    assert_eql 1, MarkdownValidator.new(dir).validate!
  end

  def test_method_heading_offsets_preserve_literal_code_examples
    code = <<~RUBY.chomp
      uri = URI.parse("http://www.ruby-lang.org/")
      # => #<URI::HTTP http://www.ruby-lang.org/>
      uri.scheme
      # => "http"
      ## Keep this comment too.
    RUBY
    klass = build_rdoc_class(full_name: "UriExamples")
    klass.add_method(rdoc_method(
      "parse",
      comment: "= Before\n\n#{code.lines.map { |line| "    #{line}" }.join}\n\n== After"
    ))

    markdown = read_generated("UriExamples.md", classes: [klass])

    assert_includes markdown, "#### Before"
    assert_includes markdown, "```ruby\n#{code}\n```"
    assert_includes markdown, "##### After"
  end

  def test_heading_offsets_only_change_html_headings_not_preformatted_text
    html = "<h1>Before</h1><pre># Literal heading\n## Literal subheading\n#\tTab comment</pre>" \
      "<h2>Between</h2><pre class=\"ruby\"># =&gt; &quot;http&quot;</pre><h3>After</h3>"

    markdown = RDoc::Generator::Markdown::HtmlInput.new(heading_level_offset: 3).render(html)

    assert_equal <<~MARKDOWN.chomp, markdown
      #### Before

      ```
      # Literal heading
      ## Literal subheading
      #\tTab comment
      ```

      ##### Between

      ```ruby
      # => "http"
      ```

      ###### After
    MARKDOWN
  end

  def test_every_definition_list_is_separated_from_following_markdown
    page = raw_html_page(
      relative_name: "definition-lists.rdoc",
      html: "<dl><dt>First</dt><dd>Result</dd></dl>\n<h2>First example</h2>\n" \
        "<dl><dt>Second</dt><dd>Result</dd></dl>\n<h2>Second example</h2>"
    )

    markdown = read_generated("definition-lists_rdoc.md", pages: [page])

    assert_includes markdown, "</dl>\n\n## First example"
    assert_includes markdown, "</dl>\n\n## Second example"
    assert_eql ["First example", "Second example"],
      Nokogiri::HTML.fragment(Commonmarker.to_html(markdown)).css("h2").map(&:text)
  end

  def test_definition_list_boundaries_do_not_rewrite_fenced_examples
    page = raw_html_page(
      relative_name: "literal-definition-list.rdoc",
      html: "<pre class=\"text\">&lt;/dl&gt;\nnot a new paragraph</pre>"
    )

    markdown = read_generated("literal-definition-list_rdoc.md", pages: [page])

    assert_eql "```text\n</dl>\nnot a new paragraph\n```\n", markdown

    unlabelled = raw_html_page(
      relative_name: "unlabelled-definition-list.rdoc",
      html: "<pre>&lt;/dl&gt;\nnot a new paragraph</pre>"
    )
    assert_equal "```\n</dl>\nnot a new paragraph\n```\n",
      read_generated("unlabelled-definition-list_rdoc.md", pages: [unlabelled])
  end

  def test_markdown_method_descriptions_preserve_explicit_heading_levels
    klass = build_rdoc_class(full_name: "Channel")
    method = rdoc_method("action_methods", comment: "#### Returns\n\n* `Set` - The action methods.")
    method.comment.format = "markdown"
    method.singleton = true
    klass.add_method(method)
    string_comment_method = rdoc_method("result")
    string_comment_method.comment = "= Result"
    klass.add_method(string_comment_method)

    markdown = read_generated("Channel.md", classes: [klass])

    assert_includes markdown, "### `action_methods()`"
    assert_includes markdown, "#### Returns"
    assert_includes markdown, "### `result()`"
    assert_includes markdown, "#### Result"
    refute_includes markdown, "##### Returns"
    refute_includes markdown, "###### Returns"
  end

  def test_method_aliases_link_to_generated_anchors
    klass = build_rdoc_class(full_name: "Nested::Aliases", description: "Alias docs")
    other = build_rdoc_class(full_name: "OtherAliases", description: "Other alias docs")
    target = rdoc_method("key?", visible: true)
    alias_method = rdoc_method("has_key?", visible: true)
    other_target = rdoc_method("find", visible: true)
    other_alias = rdoc_method("lookup", visible: true)
    alias_method.is_alias_for = target
    other_alias.is_alias_for = other_target
    klass.add_method(target)
    klass.add_method(alias_method)
    klass.add_method(other_alias)
    other.add_method(other_target)

    markdown = read_generated("Nested/Aliases.md", classes: [klass, other])

    assert_includes markdown, "Alias for: [`key?`](#method-i-key-3F)"
    assert_includes markdown, "Alias for: [`find`](../OtherAliases.md#method-i-find)"
  end

  def test_methods_do_not_list_aliases_without_generated_sections
    klass = build_rdoc_class(full_name: "Aliases")
    canonical = rdoc_method("original")
    klass.add_method(canonical)
    hidden = canonical.add_alias(RDoc::Alias.new("original", "hidden", ""), klass)
    hidden.done_documenting = true
    removed = canonical.add_alias(RDoc::Alias.new("original", "removed", ""), klass)
    removed.visibility = :private

    markdown = read_generated("Aliases.md", classes: [klass])

    assert_includes markdown, "### `original()`"
    refute_includes markdown, "Also known as:"
    refute_includes markdown, "hidden"
    refute_includes markdown, "removed"
  end

  def test_method_alias_lists_skip_detached_aliases
    klass = build_rdoc_class(full_name: "Aliases")
    canonical = rdoc_method("original", comment: "Original docs.")
    klass.add_method(canonical)
    detached = canonical.add_alias(RDoc::Alias.new("original", "detached", ""))
    canonical.add_alias(RDoc::Alias.new("original", "available", ""), klass)

    assert_nil detached.parent

    dir = generate_markdown(classes: [klass])
    markdown = File.read(File.join(dir, "Aliases.md"))

    assert_includes markdown, "Also known as: [`available`](#method-i-available)"
    refute_includes markdown, "detached"
    assert_eql 1, MarkdownValidator.new(dir).validate!
  end

  def test_method_aliases_do_not_link_to_omitted_owners
    aliases = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
    hidden_owner = build_rdoc_class(full_name: "HiddenOwner", description: "Hidden docs")
    target = rdoc_method("secret", visible: true)
    alias_method = rdoc_method("exposed", visible: true)
    alias_method.is_alias_for = target
    aliases.add_method(alias_method)
    hidden_owner.add_method(target)
    hidden_owner.done_documenting = true

    dir = generate_markdown(classes: [aliases, hidden_owner])
    markdown = File.read(File.join(dir, "Aliases.md"))

    assert_includes markdown, "Alias for: `secret`"
    refute_includes markdown, "Alias for: [`secret`]"
    assert_false File.exist?(File.join(dir, "HiddenOwner.md"))
  end

  def test_method_aliases_do_not_link_to_hidden_targets
    ["Aliases", "OtherOwner"].each do |owner_name|
      aliases = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
      owner = (owner_name == "Aliases") ? aliases : build_rdoc_class(full_name: owner_name, description: "Owner docs")
      target = rdoc_method("secret", visible: false)
      aliased = rdoc_method("exposed", visible: true)
      aliased.is_alias_for = target
      aliases.add_method(aliased)
      owner.add_method(target)

      dir = generate_markdown(classes: [aliases, owner].uniq)
      markdown = File.read(File.join(dir, "Aliases.md"))

      assert_includes markdown, "Alias for: `secret`"
      refute_includes markdown, "Alias for: [`secret`]"
      refute_includes File.read(File.join(dir, "#{owner_name}.md")), "### `secret()"
    end
  end

  def test_method_aliases_do_not_link_to_private_targets_removed_by_rdoc
    ["Aliases", "OtherOwner"].each do |owner_name|
      aliases = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
      owner = (owner_name == "Aliases") ? aliases : build_rdoc_class(full_name: owner_name, description: "Owner docs")
      target = rdoc_method("secret")
      owner.add_method(target)
      target.visibility = :private
      aliased = rdoc_method("exposed")
      aliased.is_alias_for = target
      aliases.add_method(aliased)

      dir = generate_markdown(classes: [aliases, owner].uniq)
      markdown = File.read(File.join(dir, "Aliases.md"))

      assert_includes markdown, "Alias for: `secret`"
      refute_includes markdown, "Alias for: [`secret`]"
      refute_includes index_entries(dir).map(&:first), "#{owner_name}#secret"
    end
  end

  def test_method_alias_links_to_distinct_repeated_namespace
    discarded = build_rdoc_class(full_name: "Real::Inner::Real::Thing", description: "Discarded")
    aliases = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
    ghost = rdoc_method("ghost", visible: true)
    alias_method = rdoc_method("phantom", visible: true)
    alias_method.is_alias_for = ghost
    discarded.add_method(ghost)
    aliases.add_method(alias_method)

    markdown = read_generated("Aliases.md", classes: [discarded, aliases])

    assert_includes markdown, "Alias for: [`ghost`](Real/Inner/Real/Thing.md#method-i-ghost)"
  end

  def test_generated_markdown_collapses_blank_lines_and_strips_line_endings
    page = rdoc_page(relative_name: "spacing.rdoc", comment: "Line 1  \n\n\nLine 2")

    markdown = read_generated("spacing_rdoc.md", pages: [page])

    refute_includes markdown, "\n\n\n"
    assert_includes markdown, "Line 1\n\nLine 2"
  end

  def test_blank_line_cleanup_leaves_code_blocks_alone
    html = "<p>One</p>\n<pre># step\n\nrun\n\n\n\nfinish</pre>\n<p>Two</p>\n<pre># again\n\nrun\n\n\n\nend\n```</pre>\n<h2>Three</h2>\n<p>Four</p>"
    page = raw_html_page(relative_name: "code.rdoc", html: html)

    markdown = read_generated("code_rdoc.md", pages: [page])

    assert_equal "One\n\n```\n# step\n\nrun\n\n\n\nfinish\n```\n\nTwo\n\n````\n# again\n\nrun\n\n\n\nend\n```\n````\n\n## Three\nFour\n", markdown
  end

  def test_blank_line_cleanup_continues_after_code_blocks
    klass = build_rdoc_class(full_name: "Example", description: "Doc\n\n  # step\n\n  run\n", methods: 1)

    markdown = read_generated("Example.md", classes: [klass])

    assert_includes markdown, "```ruby\n# step\n\nrun\n```\n\n## Public Instance Methods\n### `method_0()`"
  end

  def test_debug_output_is_suppressed_by_default
    page = rdoc_page(relative_name: "quiet.rdoc", comment: "Quiet page")

    stdout, = with_rdoc_debug(false) do
      capture_io do
        generate_markdown(pages: [page])
      end
    end

    assert_empty stdout
  end
end
