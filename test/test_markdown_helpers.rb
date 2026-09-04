# frozen_string_literal: true

require_relative "test_helper"

require "csv"
require "rdoc/rdoc"
require "rdoc/markdown"

class TestMarkdownHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown#initialize"
  cover "RDoc::Generator::Markdown::Conversion*"
  cover "RDoc::Generator::Markdown::Descriptions*"
  cover "RDoc::Generator::Markdown#debug"
  cover "RDoc::Generator::Markdown::Paths*"
  cover "RDoc::Generator::Markdown::CrossrefExtension*"
  cover "RDoc::Generator::Markdown::PlainVerbatimExtension*"

  def generate_markdown(classes: [], pages: [], root: nil)
    dir = stable_tmpdir("generated-markdown")
    options = generator_options(op_dir: dir, root: root)

    RDoc::Generator::Markdown.new(
      rdoc_store(classes: classes, pages: pages, options: options),
      options
    ).generate
    dir
  end

  def read_generated(path, classes: [], pages: [], root: nil)
    dir = generate_markdown(classes: classes, pages: pages, root: root)
    File.read(File.join(dir, path))
  end

  def raw_html_page(relative_name:, html:)
    rdoc_page(relative_name: relative_name, comment: "placeholder").tap do |page|
      page.define_singleton_method(:description) { html }
    end
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
    assert_includes markdown, "bird:\n- speak"
    assert_equal "\n", markdown[-1]
  end

  def test_linked_headings_are_flattened_after_intro_text
    page = rdoc_page(relative_name: "linked-heading.rdoc", comment: "Intro\n\n= {Topic}[#topic]")

    markdown = read_generated("linked-heading_rdoc.md", pages: [page])

    assert_includes markdown, "Intro\n\n# Topic<a id=\"label-Topic\"></a>"
    refute_includes markdown, "[Topic](#topic)"
  end

  def test_linked_headings_retain_rdoc_anchor_aliases
    page = rdoc_page(
      relative_name: "linked-heading-alias.rdoc",
      comment: "= {Topic}[#class-example-label-Topic]"
    )

    markdown = read_generated("linked-heading-alias_rdoc.md", pages: [page])

    assert_equal '# Topic<a id="label-Topic"></a><a id="class-example-label-Topic"></a>' + "\n", markdown
  end

  def test_linked_heading_alias_accounts_for_trailing_links
    page = raw_html_page(
      relative_name: "linked-heading-tail.rdoc",
      html: "<h1 id=\"topic-details\">\n  <a href=\"#topic\">Topic</a><a href=\"Elsewhere.md\">Details</a></h1>"
    )

    markdown = read_generated("linked-heading-tail_rdoc.md", pages: [page])

    assert_equal "# Topic[Details](Elsewhere.md)<a id=\"topic\"></a>\n", markdown
  end

  def test_heading_links_after_text_are_preserved
    page = raw_html_page(
      relative_name: "heading-link-after-text.rdoc",
      html: '<h1 id="topic">See <a href="#topic">Topic</a></h1>'
    )

    markdown = read_generated("heading-link-after-text_rdoc.md", pages: [page])

    assert_equal "# See [Topic](#topic)\n", markdown
  end

  def test_non_fragment_heading_links_are_preserved
    page = raw_html_page(
      relative_name: "external-heading-link.rdoc",
      html: '<h1 id="site"><a href="https://example.com">Site</a></h1>' \
            '<h2 id="topic"><a href="#topic">Topic</a></h2>'
    )

    markdown = read_generated("external-heading-link_rdoc.md", pages: [page])

    assert_equal "# [Site](https://example.com)\n## Topic\n", markdown
  end

  def test_rdoc_indexing_expressions_are_not_rendered_as_links
    page = raw_html_page(
      relative_name: "indexing.rdoc",
      html: '<p><a href=":csv">Mime</a> <a href="&quot;REVISION&quot;">ENV</a> ' \
            '<a href=":id">A</a> <a href=":value">Some_Class</a> ' \
            '<a href=":short">Some::A</a> <a href=":nested">Some::Thing</a> ' \
            '<a href=":option">options</a> <a href=":key">x</a> ' \
            '<a href=":invalid">some-value</a></p>'
    )

    markdown = read_generated("indexing_rdoc.md", pages: [page])

    assert_includes markdown, "`Mime[:csv]`"
    assert_includes markdown, '`ENV["REVISION"]`'
    assert_includes markdown, "`A[:id]`"
    assert_includes markdown, "`Some_Class[:value]`"
    assert_includes markdown, "`Some::A[:short]`"
    assert_includes markdown, "`Some::Thing[:nested]`"
    assert_includes markdown, "`options[:option]`"
    assert_includes markdown, "`x[:key]`"
    assert_includes markdown, "[some-value](:invalid)"
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

  def test_scheme_less_web_links_receive_https
    page = raw_html_page(
      relative_name: "web-link.rdoc",
      html: '<p><a href="www.example.com/path">www.example.com/path</a></p>'
    )

    markdown = read_generated("web-link_rdoc.md", pages: [page])

    assert_includes markdown, "[www.example.com/path](https://www.example.com/path)"
  end

  def test_links_without_href_are_preserved
    page = raw_html_page(relative_name: "missing-href.rdoc", html: "<p><a>Site</a></p>")

    assert_equal "Site\n", read_generated("missing-href_rdoc.md", pages: [page])
  end

  def test_crossrefs_to_omitted_objects_are_rendered_without_links
    source = build_rdoc_class(full_name: "Source", description: "Source docs")
    hidden = build_rdoc_class(full_name: "Hidden", description: "Hidden docs")
    hidden_method = rdoc_method("run")
    hidden.add_method(hidden_method)
    guide = rdoc_page(relative_name: "guide.rdoc", comment: "Guide")
    formatter = Class.new do
      attr_reader :rdoc_ref

      def link(*, rdoc_ref: false)
        @rdoc_ref = rdoc_ref
        "linked"
      end
    end.new
    resolver = Struct.new(:refs) do
      def resolve(name) = refs.fetch(name)
    end.new({
      "Hidden" => hidden,
      "Hidden#run" => hidden_method,
      "guide" => guide,
      "Missing" => "Missing"
    })
    formatter.extend(RDoc::Generator::Markdown::CrossrefExtension)

    formatter.with_markdown_cross_references(resolver, Set[source.object_id]) do
      assert_equal "<code>Hidden</code>", formatter.link("Hidden", "Hidden")
      assert_equal "Hidden", formatter.link("Hidden", "Hidden", false)
      assert_equal "<code>Hidden&lt;T&gt;</code>", formatter.link("Hidden", "Hidden&lt;T&gt;")
      assert_equal "Hidden&lt;T&gt;", formatter.link("Hidden", "Hidden&lt;T&gt;", false)
      assert_equal "Guide", formatter.link("guide", "Guide")
      assert_equal "linked", formatter.link(nil, "Missing")
      assert_equal "linked", formatter.link("Missing", "Missing")
      assert_false formatter.rdoc_ref
    end

    formatter.with_markdown_cross_references(resolver, Set[hidden.object_id, guide.object_id]) do
      assert_equal "linked", formatter.link("Hidden", "Hidden", false, rdoc_ref: true)
      assert_true formatter.rdoc_ref
      assert_equal "linked", formatter.link("Hidden#run", "run")
      assert_equal "linked", formatter.link("guide", "Guide")
    end
    refute_includes RDoc::Markup::ToHtmlCrossref.ancestors, RDoc::Generator::Markdown::CrossrefExtension
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

  def test_markdownify_accepts_frozen_converter_output
    page = raw_html_page(
      relative_name: "frozen.rdoc",
      html: '<h1><a href="#topic-alias">Topic</a></h1>'
    )
    converted = (+"# TopicRDocMarkdownAnchor0End").freeze

    ReverseMarkdown.stub(:convert, converted) do
      markdown = read_generated("frozen_rdoc.md", pages: [page])

      assert_equal "# Topic<a id=\"topic-alias\"></a>\n", markdown
    end
  end

  def test_markdownify_uses_github_flavored_markdown
    page = raw_html_page(relative_name: "github-flavored.rdoc", html: "<p><del>old</del></p>")

    markdown = read_generated("github-flavored_rdoc.md", pages: [page])

    assert_includes markdown, "~~old~~"
  end

  def test_markdown_unknown_tags_pass_through
    page = raw_html_page(
      relative_name: "unknown-tags.rdoc",
      html: "<p>before</p><custom>text <strong>bold</strong></custom><p>after</p>"
    )

    markdown = read_generated("unknown-tags_rdoc.md", pages: [page])

    assert_includes markdown, "before"
    assert_includes markdown, "<custom>text <strong>bold</strong></custom>"
    assert_includes markdown, "after"
  end

  def test_multiple_rdoc_heading_levels_are_normalized
    page = rdoc_page(relative_name: "levels.rdoc", comment: "== One\n\n== Two\n\n=== Deep\n\n=== Deeper")

    markdown = read_generated("levels_rdoc.md", pages: [page])

    assert_includes markdown, "## One"
    assert_includes markdown, "## Two"
    assert_includes markdown, "### Deep"
    assert_includes markdown, "### Deeper"
    refute_includes markdown, "== One"
    refute_includes markdown, "=== Deep"
  end

  def test_verbatim_pre_blocks_are_normalized_without_attributes
    page = rdoc_page(relative_name: "pre-block.rdoc", comment: "= Heading\n\n    <b>bold</b>\n    a<br>b<BR/>c<br />d\n")

    markdown = read_generated("pre-block_rdoc.md", pages: [page])

    assert_includes markdown, "```\n**bold** a\nb\nc\nd\n```"
    refute_includes markdown, "<br>"
    refute_includes markdown, "<BR/>"
    refute_includes markdown, "<br />"
  end

  def test_rdoc_ruby_pre_blocks_preserve_language_metadata
    page = rdoc_page(relative_name: "ruby-block.rdoc", comment: "= Heading\n\n    require 'erb'\n    puts :ok\n")

    markdown = read_generated("ruby-block_rdoc.md", pages: [page])

    assert_includes markdown, "```ruby\nrequire 'erb'\nputs :ok\n```"
  end

  def test_generated_verbatim_blocks_avoid_discarded_html_highlighting
    inferred_ruby = rdoc_page(
      relative_name: "inferred-ruby.rdoc",
      comment: "Example:\n\n      if ready\n        puts \"<em>&</em>\"\n      end\n"
    )
    non_ruby = rdoc_page(relative_name: "non-ruby.rdoc", comment: "Example:\n\n    unmatched }\n")
    explicit_ruby = rdoc_page(
      relative_name: "explicit-ruby.rdoc",
      comment: "```ruby\ndef broken(\n```\n"
    )
    explicit_sql = rdoc_page(
      relative_name: "explicit-sql.rdoc",
      comment: "```sql\nputs \"<row>&</row>\"\n```\n"
    )
    [explicit_ruby, explicit_sql].each { |page| page.comment.format = "markdown" }

    colorizer_calls = 0
    trace = TracePoint.new(:call) do |event|
      if event.self.equal?(RDoc::Parser::RubyColorizer) && event.method_id == :colorize
        colorizer_calls += 1
      end
    end
    dir = trace.enable do
      generate_markdown(pages: [inferred_ruby, non_ruby, explicit_ruby, explicit_sql])
    end

    assert_equal 0, colorizer_calls
    assert_includes File.read(File.join(dir, "inferred-ruby_rdoc.md")),
      "```ruby\nif ready\n  puts \"_&_\"\nend\n```"
    assert_includes File.read(File.join(dir, "non-ruby_rdoc.md")), "```\nunmatched }\n```"
    assert_equal "```ruby\ndef broken(\n```\n", File.read(File.join(dir, "explicit-ruby_rdoc.md"))
    assert_equal "```sql\nputs \"<row>&amp;</row>\"\n```\n", File.read(File.join(dir, "explicit-sql_rdoc.md"))
    assert_includes inferred_ruby.description, '<span class="ruby-identifier">puts</span>'
  end

  def test_pre_block_language_classes_are_preserved
    page = raw_html_page(relative_name: "json-block.rdoc", html: "<pre class=\"json\">{&quot;ok&quot;: true}</pre>")
    r_page = raw_html_page(relative_name: "r-block.rdoc", html: "<pre class=\"r\">1</pre>")

    markdown = read_generated("json-block_rdoc.md", pages: [page])
    r_markdown = read_generated("r-block_rdoc.md", pages: [r_page])

    assert_includes markdown, "```json\n{\"ok\": true}\n```"
    assert_includes r_markdown, "```r\n1\n```"
  end

  def test_pre_blocks_use_only_simple_language_classes
    r_page = raw_html_page(relative_name: "r.rdoc", html: "<pre class=\"r\">\nputs :ok\n</pre>")
    highlight_page = raw_html_page(relative_name: "highlight.rdoc", html: '<pre class="highlight">puts :ok</pre>')
    invalid_page = raw_html_page(relative_name: "invalid.rdoc", html: '<pre class="1bad">puts :ok</pre>')
    brush_page = raw_html_page(relative_name: "brush.rdoc", html: '<pre class="brush: sql;">SELECT 1</pre>')

    assert_equal "```r\nputs :ok\n```\n", read_generated("r_rdoc.md", pages: [r_page])
    assert_equal "```\nputs :ok\n```\n", read_generated("highlight_rdoc.md", pages: [highlight_page])
    assert_equal "```\nputs :ok\n```\n", read_generated("invalid_rdoc.md", pages: [invalid_page])
    assert_equal "```sql\nSELECT 1\n```\n", read_generated("brush_rdoc.md", pages: [brush_page])
  end

  def test_pre_blocks_preserve_reverse_markdown_parent_highlight_language
    page = raw_html_page(
      relative_name: "highlight-ruby.rdoc",
      html: '<div class="highlight-ruby"><pre>puts :ok</pre></div>'
    )
    markdown = read_generated("highlight-ruby_rdoc.md", pages: [page])

    assert_includes markdown, "```ruby\nputs :ok\n```"
  end

  def test_generated_pages_preserve_rdoc_legacy_span_anchors
    legacy_spans = 12.times.map do |index|
      %(<span id="label-Legacy-#{index}" class="legacy-anchor"></span>)
    end.join
    page = raw_html_page(
      relative_name: "legacy-anchor.rdoc",
      html: legacy_spans + '<span id="ordinary" class="ordinary">text</span>'
    )
    expected_anchors = 12.times.map { |index| %(<a id="label-Legacy-#{index}"></a>) }.join

    assert_equal expected_anchors + "text\n",
      read_generated("legacy-anchor_rdoc.md", pages: [page])
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

  def test_requiring_generator_does_not_replace_reverse_markdown_converters
    assert_equal "[Thing](:foo)",
      ReverseMarkdown.convert('<a href=":foo">Thing</a>', github_flavored: true)
    assert_equal "legacy",
      ReverseMarkdown.convert('<span class="legacy-anchor">legacy</span>', github_flavored: true)
    assert_equal "# [Heading](#heading)\n",
      ReverseMarkdown.convert('<h1><a href="#heading">Heading</a></h1>', github_flavored: true)
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

    assert_includes markdown, "bird:\n\n- speak\n- fly"
    assert_includes markdown, "fly\n\nBetween\n\nwaterfowl:"
    assert_includes markdown, "waterfowl:\n\n- swim"
    refute_includes markdown, "- \n"
    refute_includes markdown, "* speak"
    refute_includes markdown, "* swim"
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
      comment: "{EmptyAnchor}[guides/simple_rdoc.html#] [RootIntro](/guides/root-intro.md)"
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
    assert_eql "[EmptyAnchor](../guides/simple_rdoc.md#) [RootIntro](/guides/root-intro.md)\n",
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

  def test_same_page_method_aliases_do_not_link_to_hidden_targets
    klass = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
    target = rdoc_method("secret", visible: false)
    alias_method = rdoc_method("exposed", visible: true)
    alias_method.is_alias_for = target
    klass.add_method(target)
    klass.add_method(alias_method)

    markdown = read_generated("Aliases.md", classes: [klass])

    assert_includes markdown, "Alias for: `secret`"
    refute_includes markdown, "Alias for: [`secret`]"
    refute_includes markdown, "### `secret()"
  end

  def test_cross_page_method_aliases_do_not_link_to_hidden_targets
    aliases = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
    owner = build_rdoc_class(full_name: "Owner", description: "Owner docs")
    target = rdoc_method("secret", visible: false)
    alias_method = rdoc_method("exposed", visible: true)
    alias_method.is_alias_for = target
    aliases.add_method(alias_method)
    owner.add_method(target)

    dir = generate_markdown(classes: [aliases, owner])
    alias_markdown = File.read(File.join(dir, "Aliases.md"))
    owner_markdown = File.read(File.join(dir, "Owner.md"))

    assert_includes alias_markdown, "Alias for: `secret`"
    refute_includes alias_markdown, "Alias for: [`secret`]"
    refute_includes owner_markdown, "### `secret()"
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

  def test_debug_output_is_observable_through_generation
    page = rdoc_page(relative_name: "debug.rdoc", comment: "Debug page")

    stdout, = with_rdoc_debug(true) do
      capture_io do
        generate_markdown(pages: [page])
      end
    end

    assert_includes stdout, "[rdoc-markdown] Setting things up "
    assert_includes stdout, "[rdoc-markdown] Generate documentation in "
    assert_includes stdout, "[rdoc-markdown] Generate pages in "
    assert_includes stdout, "[rdoc-markdown] Generate index file in "
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
