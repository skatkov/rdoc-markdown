# frozen_string_literal: true

require_relative "test_helper"

require "csv"
require "rdoc/rdoc"
require "rdoc/markdown"

class TestMarkdownHelpers < Minitest::Test
  cover "RDoc::Generator::Markdown#markdownify"
  cover "RDoc::Generator::Markdown#describe"
  cover "RDoc::Generator::Markdown#debug"
  cover "RDoc::Generator::Markdown#method_description"
  cover "RDoc::Generator::Markdown#method_link"
  cover "RDoc::Generator::Markdown#section_description"
  cover "RDoc::Generator::Markdown#setup"
  cover "RDoc::Generator::Markdown#finalize_markdown"
  cover "RDoc::Generator::Markdown#normalize_internal_links"
  cover "RDoc::Generator::Markdown#resolve_output_path"
  cover "RDoc::Generator::Markdown#resolve_output_path_by_label"
  cover "RDoc::Generator::Markdown#plain_link_label"
  cover "RDoc::Generator::Markdown#simple_local_markdown_link?"
  cover "RDoc::Generator::Markdown#local_markdown_link_target?"
  cover "RDoc::Generator::Markdown#shift_headings"
  cover "RDoc::Generator::Markdown#normalize_definition_list_code_blocks"
  cover "RDoc::Generator::Markdown#convert_definition_list_block"
  cover "RDoc::Generator::Markdown#definition_list_line?"
  cover "RDoc::Generator::Markdown#normalize_rdoc_pre_blocks"
  cover "RDoc::Generator::Markdown#warning"
  cover "RDoc::Generator::Markdown#index_output_path_references"

  def generate_markdown(classes: [], pages: [], root: nil)
    dir = stable_tmpdir("generated-markdown")
    RDoc::Generator::Markdown.new(
      rdoc_store(classes: classes, pages: pages),
      generator_options(op_dir: dir, root: root)
    ).generate
    dir
  end

  def read_generated(path, classes: [], pages: [], root: nil)
    dir = generate_markdown(classes: classes, pages: pages, root: root)
    File.read(File.join(dir, path))
  end

  def test_pages_are_markdownified_with_headings_links_and_definition_lists
    page = rdoc_page(
      relative_name: "guide.rdoc",
      comment: "= Heading\n\n{Guide}[guide.html] {Upper}[UPPER.HTML] {Mail}[mailto:test@example.com] {Anchor}[#topic]\n" \
               "{RootGuide}[/docs/root.html?x=1] {RootPlain}[/docs/plain.html] " \
               "{Secure}[https://example.com/page.html] {PlainHttp}[http://example.com/page.html] " \
               "{MailHtml}[mailto:test.html] {AnchorHtml}[#topic.html]\n" \
               "{FilePath}[files/README.html] {FilePathAnchor}[files/README.html#top] " \
               "{ParentFile}[../files/README.html#top] " \
               "{ClassPath}[classes/Foo.html] {ParentClass}[../classes/Foo.html#top] " \
               "{ModulePath}[modules/Bar.html] {ParentModule}[../modules/Bar.html#top]\n\n" \
               "  bird::\n  * speak\n"
    )

    target = rdoc_page(relative_name: "README", comment: "= README")
    foo = build_rdoc_class(full_name: "Foo", description: "Foo docs")
    bar = build_rdoc_class(full_name: "Bar", description: "Bar docs")
    markdown = nil
    _, stderr = capture_io do
      markdown = read_generated("guide_rdoc.md", classes: [foo, bar], pages: [page, target])
    end

    assert_includes markdown, "# Heading"
    assert_includes markdown, "Guide Upper"
    assert_includes stderr, '[rdoc-markdown] removed unresolved local link "guide.md" with label "Guide"'
    assert_includes markdown, "[Mail](mailto:test@example.com)"
    assert_includes markdown, "[Anchor](#topic)"
    assert_includes markdown, "[RootGuide](docs/root.md?x=1)"
    assert_includes markdown, "[RootPlain](docs/plain.md)"
    assert_includes markdown, "[Secure](https://example.com/page.html)"
    assert_includes markdown, "[PlainHttp](http://example.com/page.html)"
    assert_includes markdown, "[MailHtml](mailto:test.html)"
    assert_includes markdown, "[AnchorHtml](#topic.html)"
    assert_includes markdown, "[FilePath](README.md)"
    assert_includes markdown, "[FilePathAnchor](README.md#top)"
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

    assert_includes markdown, "Intro\n\n# Topic"
    refute_includes markdown, "[Topic](#topic)"
  end

  def test_empty_reverse_markdown_results_do_not_emit_frozen_literal_warnings
    skip "Ruby warning categories are unavailable" unless Warning.respond_to?(:[]) && Warning.respond_to?(:[]=)

    original = Warning[:deprecated]
    Warning[:deprecated] = true
    page = rdoc_page(relative_name: "empty.rdoc", comment: "")

    _, stderr = capture_io do
      read_generated("empty_rdoc.md", pages: [page])
    end

    refute_includes stderr, "literal string will be frozen"
  ensure
    Warning[:deprecated] = original if defined?(original)
  end

  def test_multiple_rdoc_heading_levels_are_normalized
    page = rdoc_page(relative_name: "levels.rdoc", comment: "== One\n\n== Two\n\n=== Deep\n\n=== Deeper")

    markdown = read_generated("levels_rdoc.md", pages: [page])

    assert_includes markdown, "## One\n\n## Two"
    assert_includes markdown, "### Deep\n\n### Deeper"
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

  def test_invalid_definition_list_blocks_remain_plain_text
    page = rdoc_page(relative_name: "invalid-definition.rdoc", comment: "= Heading\n\n  bird::\n  plain text\n")

    markdown = read_generated("invalid-definition_rdoc.md", pages: [page])

    assert_includes markdown, "```\nbird::\nplain text\n```"
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
    guide = rdoc_page(relative_name: "guides/intro.rdoc", comment: "= Intro")
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
                "{Missing}[missing/path.html#part] {Secure}[https://example.com/page.md] " \
               "{Mail}[mailto:test@example.com] {Anchor}[#topic.md] " \
               "[Sibling](nested/../sibling.md)"
    )

    dir = nil
    _, stderr = capture_io do
      dir = generate_markdown(pages: [guide, api, sibling, simple_intro, single, empty_anchor, readme])
    end
    markdown = File.read(File.join(dir, "docs/readme_rdoc.md"))

    assert_includes markdown, "[Intro](../guides/intro_rdoc.md#top)"
    assert_includes markdown, "[API](../guides/api_rdoc.md)"
    assert_includes markdown, "[Missing](missing/path.md#part)"
    assert_includes markdown, "[Secure](https://example.com/page.md)"
    assert_includes markdown, "[Mail](mailto:test@example.com)"
    assert_includes markdown, "[Anchor](#topic.md)"
    assert_includes markdown, "[Sibling](sibling.md)"
    refute_includes stderr, 'resolved local link "missing/path.md#part"'
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

  def test_unresolved_simple_internal_links_are_rendered_as_text_with_warning
    klass = build_rdoc_class(
      full_name: "Minitest::Reportable",
      description: "Shared code for anything passed to a {+Reporter+}[Reporter.html]."
    )

    markdown = nil
    _, stderr = capture_io do
      markdown = read_generated("Minitest/Reportable.md", classes: [klass])
    end

    assert_includes markdown, "passed to a `Reporter`."
    refute_includes markdown, "[Reporter](Reporter.md)"
    warning = '[rdoc-markdown] removed unresolved local link "Reporter.md" with label "Reporter"'
    assert_includes stderr, warning
    assert_equal 1, stderr.scan(warning).count
    refute_includes stderr, 'with label "`Reporter`"'
  end

  def test_legacy_class_paths_finalize_links_relative_to_their_own_output
    root = build_rdoc_class(full_name: "Minitest", description: "Root docs")
    path_expander = build_rdoc_class(
      full_name: "Minitest::VendoredPathExpander::Minitest::VendoredPathExpander::Minitest::PathExpander",
      description: "Returns a hash mapping [Minitest](../../../Minitest.md) runnable classes."
    )

    dir = nil
    _, stderr = capture_io do
      dir = generate_markdown(classes: [root, path_expander])
    end

    assert_includes File.read(File.join(dir, "Minitest/PathExpander.md")), "[Minitest](../Minitest.md)"
    assert_includes File.read(File.join(
      dir,
      "Minitest/VendoredPathExpander/Minitest/VendoredPathExpander/Minitest/PathExpander.md"
    )), "[Minitest](../../../../../Minitest.md)"
    assert_includes stderr, '[rdoc-markdown] resolved local link "../../../Minitest.md" by label "Minitest"'
  end

  def test_label_resolution_prefers_exact_names_when_simple_names_are_ambiguous
    root = build_rdoc_class(full_name: "Root", description: "Root docs")
    other_root = build_rdoc_class(full_name: "Other::Root", description: "Other root docs")
    synthetic = build_rdoc_class(
      full_name: "Vendored::Inner::Vendored::Thing",
      description: "Synthetic docs"
    )
    source = build_rdoc_class(
      full_name: "Docs::Thing",
      description: "See [Root](../../Root.md), [Vendored::Thing](../../Vendored/Thing.md), " \
                   "and [Vendored::Inner::Vendored::Thing](../../Vendored/Inner/Vendored/Thing.md)."
    )

    dir = nil
    capture_io do
      dir = generate_markdown(classes: [root, other_root, synthetic, source])
    end

    markdown = File.read(File.join(dir, "Docs/Thing.md"))

    assert_includes markdown, "[Root](../Root.md)"
    assert_includes markdown, "[Vendored::Thing](../Vendored/Thing.md)"
    assert_includes markdown, "[Vendored::Inner::Vendored::Thing](../Vendored/Thing.md)"
  end

  def test_label_resolution_leaves_ambiguous_simple_names_unresolved
    alpha = build_rdoc_class(full_name: "Alpha::Thing", description: "Alpha docs")
    beta = build_rdoc_class(full_name: "Beta::Thing", description: "Beta docs")
    page = rdoc_page(relative_name: "docs/ambiguous.rdoc", comment: "See [Thing](../Thing.md).")

    dir = nil
    _, stderr = capture_io do
      dir = generate_markdown(classes: [alpha, beta], pages: [page])
    end

    assert_includes File.read(File.join(dir, "docs/ambiguous_rdoc.md")), "[Thing](../Thing.md)"
    refute_includes stderr, 'resolved local link "../Thing.md" by label "Thing"'
  end

  def test_label_resolution_uses_unambiguous_simple_names
    target = build_rdoc_class(full_name: "Namespace::Thing", description: "Target docs")
    source = build_rdoc_class(
      full_name: "Docs::Source",
      description: "See {+Thing+}[../Thing.html]."
    )

    dir = nil
    _, stderr = capture_io do
      dir = generate_markdown(classes: [target, source])
    end

    assert_includes File.read(File.join(dir, "Docs/Source.md")), "[`Thing`](../Namespace/Thing.md)"
    assert_includes stderr, 'resolved local link "../Thing.md" by label "Thing"'
    refute_includes stderr, 'by label "`Thing`"'
  end

  def test_label_resolution_only_uses_local_markdown_targets
    target = build_rdoc_class(full_name: "Namespace::Thing", description: "Target docs")
    page = rdoc_page(
      relative_name: "docs/targets.rdoc",
      comment: "See {Thing}[../Thing.html#], {Thing}[../Thing.html#topic], " \
               "{Thing}[../Thing.html?version=1], {Thing}[http://example.com/Thing.md], " \
               "{Thing}[HTTPS://example.com/Thing.md], " \
               "{Thing}[#Thing.md], and {Thing}[Thing.txt]."
    )

    dir = nil
    capture_io do
      dir = generate_markdown(classes: [target], pages: [page])
    end

    markdown = File.read(File.join(dir, "docs/targets_rdoc.md"))

    assert_includes markdown, "[Thing](../Namespace/Thing.md#)"
    assert_includes markdown, "[Thing](../Namespace/Thing.md#topic)"
    assert_includes markdown, "[Thing](../Namespace/Thing.md?version=1)"
    assert_includes markdown, "[Thing](http://example.com/Thing.md)"
    assert_includes markdown, "[Thing](HTTPS://example.com/Thing.md)"
    assert_includes markdown, "[Thing](#Thing.md)"
    assert_includes markdown, "[Thing](Thing.txt)"
  end

  def test_label_resolution_does_not_rewrite_mailto_markdown_targets
    raw_page_class = Struct.new(:relative_name, :description, :store) do
      def text?
        true
      end

      def display?
        true
      end

      def base_name
        File.basename(relative_name)
      end

      def page_name
        File.basename(relative_name, ".*")
      end
    end
    target = build_rdoc_class(full_name: "Namespace::Thing", description: "Target docs")
    page = raw_page_class.new(
      "docs/mailto.raw",
      'See <a href="mailto:test@example.com/Thing.md">Thing</a>.'
    )

    dir = nil
    capture_io do
      dir = generate_markdown(classes: [target], pages: [page])
    end

    assert_includes File.read(File.join(dir, "docs/mailto_raw.md")), "[Thing](mailto:test@example.com/Thing.md)"
  end

  def test_class_and_method_descriptions_are_markdownified
    klass = build_rdoc_class(full_name: "Docs::Thing", description: "= Class Topic")
    klass.add_section("Overview", RDoc::Comment.new("= Section Topic"))
    klass.add_constant(rdoc_constant("VALUE"))
    method = rdoc_method("run", visible: true, comment: "= Method Topic\n\n=== Method Detail")
    klass.add_method(method)
    klass.add_method(rdoc_method("plain", visible: true))

    markdown = read_generated("Docs/Thing.md", classes: [klass])

    assert_includes markdown, "# Class Docs::Thing"
    assert_includes markdown, "# Class Topic"
    refute_includes markdown, "## Class Topic"
    refute_includes markdown, "\n\n\n"
    assert_includes markdown, "# Class Topic\n\n### Constants"
    assert_includes markdown, "#### `VALUE`"
    assert_includes markdown, "Not documented."
    assert_includes markdown, "## Overview"
    assert_includes markdown, "### Section Topic"
    refute_includes markdown, "\n# Section Topic\n"
    assert_includes markdown, "#### `run()`"
    assert_includes markdown, "\n##### Method Topic\n\n###### Method Detail\n"
    refute_includes markdown, "\n###### Method Topic\n"
    refute_includes markdown, "\n####### Method Detail\n"
    refute_includes markdown, "\n## Method Detail\n"
    assert_includes markdown, "#### `plain()`\n<a id=\"method-i-plain\"></a>\n\nNot documented."
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
