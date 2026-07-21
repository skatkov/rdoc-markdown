# frozen_string_literal: true

require_relative "test_helper"

require "csv"
require "rdoc/rdoc"
require "rdoc/markdown"

class TestMarkdownHelpers < Minitest::Test
  DEFAULT_MARKDOWN_UNKNOWN_TAGS = Object.new.freeze

  cover "RDoc::Generator::Markdown.setup_options"
  cover "RDoc::Generator::Markdown.validate_markdown_unknown_tags"
  cover "RDoc::Generator::Markdown#initialize"
  cover "RDoc::Generator::Markdown#markdownify"
  cover "RDoc::Generator::Markdown#describe"
  cover "RDoc::Generator::Markdown#debug"
  cover "RDoc::Generator::Markdown#method_description"
  cover "RDoc::Generator::Markdown#method_link"
  cover "RDoc::Generator::Markdown#section_description"
  cover "RDoc::Generator::Markdown#finalize_markdown"
  cover "RDoc::Generator::Markdown#normalize_internal_links"
  cover "RDoc::Generator::Markdown::OptionsExtension#init_ivars"
  cover "RDoc::Generator::Markdown::OptionsExtension#init_with"
  cover "RDoc::Generator::Markdown::OptionsExtension#override"
  cover "RDoc::Generator::Markdown#resolve_output_path"
  cover "RDoc::Generator::Markdown#shift_headings"
  cover "RDoc::Generator::Markdown#normalize_definition_list_code_blocks"
  cover "RDoc::Generator::Markdown#convert_definition_list_block"
  cover "RDoc::Generator::Markdown#definition_list_line?"
  cover "RDoc::Generator::Markdown::CrossrefExtension#link"
  cover "ReverseMarkdown::Converters::RDocMarkdownPre*"
  cover "ReverseMarkdown::Converters::RDocMarkdownSpan*"

  def generate_markdown(classes: [], pages: [], root: nil, markdown_unknown_tags: DEFAULT_MARKDOWN_UNKNOWN_TAGS)
    dir = stable_tmpdir("generated-markdown")
    options = generator_options(op_dir: dir, root: root)
    options.markdown_unknown_tags = markdown_unknown_tags unless markdown_unknown_tags.equal?(DEFAULT_MARKDOWN_UNKNOWN_TAGS)

    RDoc::Generator::Markdown.new(
      rdoc_store(classes: classes, pages: pages),
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
               "{RootGuide}[/docs/root.html?x=1] {RootPlain}[/docs/plain.html] " \
               "{Secure}[https://example.com/page.html] {PlainHttp}[http://example.com/page.html] " \
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
    assert_includes markdown, "[Secure](https://example.com/page.html)"
    assert_includes markdown, "[PlainHttp](http://example.com/page.html)"
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

    assert_includes markdown, "Intro\n\n<a id=\"label-Topic\"></a>\n# Topic"
    refute_includes markdown, "[Topic](#topic)"
  end

  def test_linked_headings_retain_rdoc_anchor_aliases
    page = rdoc_page(
      relative_name: "linked-heading-alias.rdoc",
      comment: "= {Topic}[#class-example-label-Topic]"
    )

    markdown = read_generated("linked-heading-alias_rdoc.md", pages: [page])

    assert_includes markdown, '# Topic<a id="class-example-label-Topic"></a>'
  end

  def test_linked_heading_alias_accounts_for_trailing_links
    page = rdoc_page(relative_name: "linked-heading-tail.rdoc", comment: "placeholder")

    ReverseMarkdown.stub(:convert, "# [Topic](#topic)[Details](Elsewhere.md)") do
      markdown = read_generated("linked-heading-tail_rdoc.md", pages: [page])

      assert_equal "# Topic[Details](Elsewhere.md)<a id=\"topic\"></a>\n", markdown
    end
  end

  def test_rdoc_indexing_expressions_are_not_rendered_as_links
    page = raw_html_page(
      relative_name: "indexing.rdoc",
      html: '<p><a href=":csv">Mime</a> <a href="&quot;REVISION&quot;">ENV</a> <a href=":id">A</a></p>'
    )

    markdown = read_generated("indexing_rdoc.md", pages: [page])

    assert_includes markdown, "`Mime[:csv]`"
    assert_includes markdown, '`ENV["REVISION"]`'
    assert_includes markdown, "`A[:id]`"
  end

  def test_scheme_less_web_links_receive_https
    page = raw_html_page(
      relative_name: "web-link.rdoc",
      html: '<p><a href="www.example.com/path">www.example.com/path</a></p>'
    )

    markdown = read_generated("web-link_rdoc.md", pages: [page])

    assert_includes markdown, "[www.example.com/path](https://www.example.com/path)"
  end

  def test_crossrefs_to_omitted_objects_are_rendered_without_links
    source = build_rdoc_class(full_name: "Source", description: "Source docs")
    hidden = build_rdoc_class(full_name: "Hidden", description: "Hidden docs")
    hidden_method = rdoc_method("run")
    hidden.add_method(hidden_method)
    guide = rdoc_page(relative_name: "guide.rdoc", comment: "Guide")
    options = source.store.options
    formatter = RDoc::Markup::ToHtmlCrossref.new(options, "Source.html", source)
    resolver = Struct.new(:refs) { def resolve(name, *) = refs.fetch(name) }.new({
      "Hidden" => hidden,
      "Hidden#run" => hidden_method,
      "guide" => guide,
      "Missing" => "Missing"
    })
    formatter.instance_variable_set(:@cross_reference, resolver)

    assert_includes formatter.link("Hidden", "Hidden"), '<a href="Hidden.html"><code>Hidden</code></a>'

    options.markdown_output_object_ids = Set.new
    assert_equal "<code>Hidden</code>", formatter.link("Hidden", "Hidden")
    assert_equal "Hidden", formatter.link("Hidden", "Hidden", false)
    assert_equal "<code>Hidden&lt;T&gt;</code>", formatter.link("Hidden", "Hidden<T>")
    assert_equal "Hidden&lt;T&gt;", formatter.link("Hidden", "Hidden<T>", false)

    options.markdown_output_object_ids << hidden.object_id
    assert_includes formatter.link("Hidden", "Hidden"), '<a href="Hidden.html"><code>Hidden</code></a>'
    assert_includes formatter.link("Hidden#run", "run"), 'href="Hidden.html#method-i-run"'

    assert_equal "Guide", formatter.link("guide", "Guide")
    options.markdown_output_object_ids << guide.object_id
    assert_includes formatter.link("guide", "Guide"), '<a href="guide_rdoc.html">Guide</a>'

    options.warn_missing_rdoc_ref = true
    stdout, = capture_io { assert_equal "Missing", formatter.link("Missing", "Missing") }
    assert_empty stdout
  end

  def test_markdownify_accepts_frozen_converter_output
    page = rdoc_page(relative_name: "frozen.rdoc", comment: "= Topic")
    converted = (+"# [Topic](#topic)").freeze

    ReverseMarkdown.stub(:convert, converted) do
      markdown = read_generated("frozen_rdoc.md", pages: [page])

      assert_equal "# Topic\n", markdown
    end
  end

  def test_markdownify_uses_github_flavored_markdown
    page = raw_html_page(relative_name: "github-flavored.rdoc", html: "<p><del>old</del></p>")

    markdown = read_generated("github-flavored_rdoc.md", pages: [page])

    assert_includes markdown, "~~old~~"
  end

  def test_markdown_unknown_tags_defaults_to_pass_through
    assert_equal :pass_through, RDoc::Options.new.markdown_unknown_tags

    page = raw_html_page(
      relative_name: "unknown-tags.rdoc",
      html: "<p>before</p><custom>text <strong>bold</strong></custom><p>after</p>"
    )

    markdown = read_generated("unknown-tags_rdoc.md", pages: [page])

    assert_includes markdown, "before"
    assert_includes markdown, "<custom>text <strong>bold</strong></custom>"
    assert_includes markdown, "after"
  end

  def test_markdown_unknown_tags_can_bypass_tags
    page = raw_html_page(
      relative_name: "bypass-tags.rdoc",
      html: "<p>before</p><custom>text <strong>bold</strong></custom><p>after</p>"
    )

    markdown = File.read(File.join(generate_markdown(pages: [page], markdown_unknown_tags: :bypass), "bypass-tags_rdoc.md"))

    assert_includes markdown, "before"
    assert_includes markdown, "text **bold**"
    assert_includes markdown, "after"
    refute_includes markdown, "<custom>"
  end

  def test_markdown_unknown_tags_can_drop_tags_and_content
    page = raw_html_page(
      relative_name: "drop-tags.rdoc",
      html: "<p>before</p><custom>text <strong>bold</strong></custom><p>after</p>"
    )

    markdown = File.read(File.join(generate_markdown(pages: [page], markdown_unknown_tags: :drop), "drop-tags_rdoc.md"))

    assert_includes markdown, "before"
    assert_includes markdown, "after"
    refute_includes markdown, "text"
    refute_includes markdown, "<custom>"
  end

  def test_markdown_unknown_tags_can_raise
    page = raw_html_page(
      relative_name: "raise-tags.rdoc",
      html: "<p>before</p><custom>text</custom><p>after</p>"
    )

    assert_raises(ReverseMarkdown::UnknownTagError) do
      generate_markdown(pages: [page], markdown_unknown_tags: :raise)
    end
  end

  def test_markdown_unknown_tags_rejects_invalid_values
    options = generator_options(op_dir: stable_tmpdir("invalid-unknown-tags"))
    options.markdown_unknown_tags = :explode

    error = assert_raises(OptionParser::InvalidArgument) do
      RDoc::Generator::Markdown.new(rdoc_store, options)
    end

    assert_includes error.message, "invalid markdown_unknown_tags: :explode"
    assert_includes error.message, "expected one of: :pass_through, :drop, :bypass, :raise"
  end

  def test_markdown_unknown_tags_can_be_set_by_cli_option
    options = RDoc::Options.new.parse(%w[--format=markdown --markdown-unknown-tags=drop])

    assert_equal :drop, options.markdown_unknown_tags
    assert_includes options.option_parser.help, "--markdown-unknown-tags=MODE"
    assert_includes options.option_parser.help, "pass_through, drop, bypass, raise"
  end

  def test_markdown_unknown_tags_loads_from_rdoc_options_hash
    options = RDoc::Options.new("markdown_unknown_tags" => :bypass, "visibility" => :private)

    assert_equal :bypass, options.markdown_unknown_tags
    assert_equal :private, options.visibility
  end

  def test_markdown_unknown_tags_rdoc_options_hash_keeps_default_when_key_is_absent
    options = RDoc::Options.new({})

    assert_equal :pass_through, options.markdown_unknown_tags
  end

  def test_markdown_unknown_tags_loads_from_serialized_rdoc_options
    RDoc.load_yaml

    options = YAML.safe_load(
      "--- !ruby/object:RDoc::Options\nencoding: UTF-8\nstatic_path: []\nrdoc_include: []\nmarkdown_unknown_tags: :drop\n",
      permitted_classes: [RDoc::Options, Symbol]
    )

    assert_equal :drop, options.markdown_unknown_tags
    assert_equal Encoding::UTF_8, options.encoding
    assert_false options.quiet
  end

  def test_markdown_unknown_tags_serialized_rdoc_options_keep_default_when_key_is_absent
    RDoc.load_yaml

    options = YAML.safe_load(
      "--- !ruby/object:RDoc::Options\nencoding: UTF-8\nstatic_path: []\nrdoc_include: []\n",
      permitted_classes: [RDoc::Options, Symbol]
    )

    assert_equal :pass_through, options.markdown_unknown_tags
  end

  def test_markdown_unknown_tags_rejects_nil_from_serialized_rdoc_options
    RDoc.load_yaml
    options = YAML.safe_load(
      "--- !ruby/object:RDoc::Options\nencoding: UTF-8\nstatic_path: []\nrdoc_include: []\nmarkdown_unknown_tags:\n",
      permitted_classes: [RDoc::Options, Symbol]
    )

    error = assert_raises(OptionParser::InvalidArgument) do
      RDoc::Generator::Markdown.new(rdoc_store, options)
    end

    assert_includes error.message, "invalid markdown_unknown_tags: nil"
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

  def test_pre_block_language_classes_are_preserved
    page = raw_html_page(relative_name: "json-block.rdoc", html: "<pre class=\"json\">{&quot;ok&quot;: true}</pre>")
    r_page = raw_html_page(relative_name: "r-block.rdoc", html: "<pre class=\"r\">1</pre>")

    markdown = read_generated("json-block_rdoc.md", pages: [page])
    r_markdown = read_generated("r-block_rdoc.md", pages: [r_page])

    assert_includes markdown, "```json\n{\"ok\": true}\n```"
    assert_includes r_markdown, "```r\n1\n```"
  end

  def test_pre_converter_uses_only_simple_language_classes
    assert_equal "```r\nputs :ok\n```\n", ReverseMarkdown.convert("<pre class=\"r\">\nputs :ok\n</pre>", github_flavored: true)
    assert_equal "```\nputs :ok\n```\n", ReverseMarkdown.convert("<pre class=\"highlight\">puts :ok</pre>", github_flavored: true)
    assert_equal "```\nputs :ok\n```\n", ReverseMarkdown.convert("<pre class=\"1bad\">puts :ok</pre>", github_flavored: true)
  end

  def test_pre_converter_preserves_reverse_markdown_parent_highlight_language
    markdown = ReverseMarkdown.convert("<div class=\"highlight-ruby\"><pre>puts :ok</pre></div>", github_flavored: true)

    assert_includes markdown, "```ruby\nputs :ok\n```"
  end

  def test_span_converter_preserves_only_rdoc_legacy_anchors
    assert_equal '<a id="label-Legacy+heading"></a>',
      ReverseMarkdown.convert('<span id="label-Legacy+heading" class="legacy-anchor"></span>', github_flavored: true)
    assert_equal "text",
      ReverseMarkdown.convert('<span id="ordinary" class="ordinary">text</span>', github_flavored: true)
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
    sibling = rdoc_page(relative_name: "docs/sibling", comment: "= Sibling")
    simple_intro = rdoc_page(relative_name: "guides/intro", comment: "Intro")
    single = rdoc_page(relative_name: "docs/single.rdoc", comment: "{Intro}[guides/intro_rdoc.html#top]")
    empty_anchor = rdoc_page(
      relative_name: "docs/empty-anchor.rdoc",
      comment: "[EmptyAnchor](guides/intro.md#) [RootIntro](/guides/intro.md)"
    )
    readme = rdoc_page(
      relative_name: "docs/readme.rdoc",
      comment: "{Intro}[guides/intro_rdoc.html#top] {API}[guides/api_rdoc.html] " \
                 "{Missing}[missing/path.html#part] " \
                 "{Secure}[https://example.com/page.md#class-example-label-Topic] " \
                 "{Mail}[mailto:test@example.com] {Anchor}[#topic.md] " \
                 "[Sibling](nested/../sibling.md) " \
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
    assert_includes markdown, "[Sibling](sibling.md)"
    assert_includes markdown,
      "[Legacy](../guides/intro_rdoc.md#class-ActiveSupport::Messages::MessageVerifier-label-Signing+is+not+encryption)"
    assert_includes markdown, "[Query](../guides/intro_rdoc.md?tag=-label-test)"
    assert_eql "[Intro](../guides/intro_rdoc.md#top)\n", File.read(File.join(dir, "docs/single_rdoc.md"))
    assert_eql "[EmptyAnchor](../guides/intro.md#) [RootIntro](../guides/intro.md)\n",
      File.read(File.join(dir, "docs/empty-anchor_rdoc.md"))
  end

  def test_internal_links_resolve_root_segment_candidates
    direct = rdoc_page(relative_name: "pages/guides/direct", comment: "Direct")
    rooted = rdoc_page(relative_name: "pages/guides/rooted", comment: "Rooted")
    nested = rdoc_page(relative_name: "pages/pages/guides/nested", comment: "Nested")
    readme = rdoc_page(
      relative_name: "pages/docs/readme.rdoc",
      comment: "[Direct](guides/direct.md) [Rooted](pages/guides/rooted.md) " \
               "[Nested](pages/guides/nested.md)"
    )

    dir = generate_markdown(pages: [direct, rooted, nested, readme], root: "pages")

    assert_eql "[Direct](../guides/direct.md) [Rooted](../guides/rooted.md) " \
               "[Nested](../pages/guides/nested.md)\n",
      File.read(File.join(dir, "docs/readme_rdoc.md"))
  end

  def test_class_and_method_descriptions_are_markdownified
    klass = build_rdoc_class(full_name: "Docs::Thing", description: "= Class Topic")
    klass.add_section("Overview", RDoc::Comment.new("= Section Topic"))
    klass.add_constant(rdoc_constant("VALUE"))
    constructor = rdoc_method("new", visible: true, comment: "Creates a new entry using +str+.", signature: "(str)")
    constructor.singleton = true
    method = rdoc_method("run", visible: true, comment: "= Method Topic\n\n=== Method Detail")
    klass.add_method(constructor)
    klass.add_method(method)
    klass.add_method(rdoc_method("plain", visible: true))

    markdown = read_generated("Docs/Thing.md", classes: [klass])

    assert_includes markdown, "# Class Docs::Thing"
    assert_includes markdown, "# Class Topic"
    refute_includes markdown, "## Class Topic"
    refute_includes markdown, "\n\n\n"
    assert_includes markdown, "# Class Topic<a id=\"class-docs-thing-class-topic\"></a>\n\n### Constants"
    assert_includes markdown, "#### `VALUE`<a id=\"VALUE\"></a>\nNot documented."
    assert_includes markdown, "## Overview"
    assert_includes markdown, "### Section Topic"
    refute_includes markdown, "\n# Section Topic\n"
    assert_includes markdown, "#### `run()`"
    assert_includes markdown,
      "\n<a id=\"method-i-run-label-Method+Topic\"></a>\n" \
      "##### Method Topic<a id=\"method-i-run-method-topic\"></a>\n" \
      "<a id=\"method-i-run-label-Method+Detail\"></a>\n" \
      "###### Method Detail<a id=\"method-i-run-method-detail\"></a>\n"
    refute_includes markdown, "\n###### Method Topic\n"
    refute_includes markdown, "\n####### Method Detail\n"
    refute_includes markdown, "\n## Method Detail\n"
    assert_includes markdown, "#### `new(str)`<a id=\"method-c-new\"></a>\nCreates a new entry using `str`."
    refute_includes markdown, "#### `new(str)`<a id=\"method-c-new\"></a>\n\nCreates"
    assert_includes markdown, "#### `plain()`<a id=\"method-i-plain\"></a>\nNot documented."
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

  def test_method_alias_cannot_link_to_discarded_duplicate
    selected = build_rdoc_class(full_name: "Real::Thing", description: "Selected", methods: 2)
    discarded = build_rdoc_class(full_name: "Real::Inner::Real::Thing", description: "Discarded")
    aliases = build_rdoc_class(full_name: "Aliases", description: "Alias docs")
    ghost = rdoc_method("ghost", visible: true)
    alias_method = rdoc_method("phantom", visible: true)
    alias_method.is_alias_for = ghost
    discarded.add_method(ghost)
    aliases.add_method(alias_method)

    assert_raises(KeyError) { generate_markdown(classes: [selected, discarded, aliases]) }
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
