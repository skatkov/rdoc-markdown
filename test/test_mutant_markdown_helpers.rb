# frozen_string_literal: true

require_relative 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/markdown'
require 'set'

class TestMutantMarkdownHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#markdownify'
  cover 'RDoc::Generator::Markdown#describe'
  cover 'RDoc::Generator::Markdown#debug'
  cover 'RDoc::Generator::Markdown#method_description'
  cover 'RDoc::Generator::Markdown#method_link'
  cover 'RDoc::Generator::Markdown#section_description'
  cover 'RDoc::Generator::Markdown#finalize_markdown'
  cover 'RDoc::Generator::Markdown#normalize_internal_links'
  cover 'RDoc::Generator::Markdown#resolve_output_path'
  cover 'RDoc::Generator::Markdown#candidate_with_parent_reductions'
  cover 'RDoc::Generator::Markdown#shift_headings'
  cover 'RDoc::Generator::Markdown#section_description_html'
  cover 'RDoc::Generator::Markdown#normalize_definition_list_code_blocks'
  cover 'RDoc::Generator::Markdown#convert_definition_list_block'
  cover 'RDoc::Generator::Markdown#definition_list_line?'
  cover 'RDoc::Generator::Markdown#normalize_rdoc_pre_blocks'
  cover 'RDoc::Generator::Markdown#unindent_text'

  def probe
    RDocMarkdownGeneratorProbes::MarkdownProbe.new(nil, generator_options(op_dir: stable_tmpdir('probe')))
  end

  def link_probe(known_output_paths:, root_path_segment: 'docs-root')
    markdown_probe = probe
    markdown_probe.instance_variable_set(:@known_output_paths, Set.new(known_output_paths))
    markdown_probe.instance_variable_set(:@root_path_segment, root_path_segment)
    markdown_probe
  end

  def method_description_probe(describe_return: '')
    markdown_probe = RDocMarkdownGeneratorProbes::MethodDescriptionProbe.new(nil, generator_options(op_dir: stable_tmpdir('method-description-probe')))
    markdown_probe.describe_return = describe_return
    markdown_probe
  end

  def method_link_probe(output_paths: {})
    markdown_probe = RDocMarkdownGeneratorProbes::MethodLinkProbe.new(nil, generator_options(op_dir: stable_tmpdir('method-link-probe')))
    markdown_probe.output_paths = output_paths
    markdown_probe
  end

  def test_normalize_rdoc_pre_blocks_converts_breaks_strips_tags_and_unescapes_entities
    html = '<pre>line 1<br><code>line &amp; 2</code></pre>'

    assert_eql "<pre>line 1\nline & 2</pre>", probe.normalize_rdoc_pre_blocks(html)
  end

  def test_normalize_rdoc_pre_blocks_rewrites_all_pre_blocks
    html = '<pre>first<br>line</pre><p>gap</p><pre>second<br>line</pre>'

    assert_eql "<pre>first\nline</pre><p>gap</p><pre>second\nline</pre>", probe.normalize_rdoc_pre_blocks(html)
  end

  def test_normalize_rdoc_pre_blocks_treats_br_tags_case_insensitively
    html = '<pre>first<BR>line</pre>'

    assert_eql "<pre>first\nline</pre>", probe.normalize_rdoc_pre_blocks(html)
  end

  def test_normalize_rdoc_pre_blocks_rewrites_all_break_tags_within_one_block
    html = '<pre>first<br>second<br>third</pre>'

    assert_eql "<pre>first\nsecond\nthird</pre>", probe.normalize_rdoc_pre_blocks(html)
  end

  def test_normalize_rdoc_pre_blocks_matches_multiline_pre_bodies
    html = "<pre>first\nsecond</pre>"

    assert_eql "<pre>first\nsecond</pre>", probe.normalize_rdoc_pre_blocks(html)
  end

  def test_normalize_rdoc_pre_blocks_normalizes_multiline_bodies_with_inner_tags
    html = "<pre>first\n<code>second &amp; third</code></pre>"

    assert_eql "<pre>first\nsecond & third</pre>", probe.normalize_rdoc_pre_blocks(html)
  end

  def test_unindent_text_removes_common_indentation_only
    text = "    one\n      two\n\n    three\n"

    assert_eql "one\n  two\n\nthree\n", probe.unindent_text(text)
  end

  def test_unindent_text_uses_smallest_non_blank_indent_across_lines
    text = "    one\n  two\n      three\n"

    assert_eql "  one\ntwo\n    three\n", probe.unindent_text(text)
  end

  def test_unindent_text_returns_blank_only_text_unchanged
    text = "\n   \n"

    assert_eql text, probe.unindent_text(text)
  end

  def test_unindent_text_returns_original_object_when_indent_is_zero
    text = "one\n  two\n"

    assert_same text, probe.unindent_text(text)
  end

  def test_unindent_text_ignores_whitespace_only_lines_when_computing_indent
    text = "   \n\t \n    one\n"

    assert_eql "\n\none\n", probe.unindent_text(text)
  end

  def test_shift_headings_offsets_and_caps_levels
    markdown = "# One\n##### Two\n"

    assert_eql "### One\n###### Two\n", probe.shift_headings(markdown, 2)
    assert_eql markdown, probe.shift_headings(markdown, 0)
  end

  def test_definition_list_line_detects_allowed_lines
    assert_true probe.definition_list_line?('item::')
    assert_true probe.definition_list_line?('  * value')
    assert_true probe.definition_list_line?('   ')
    assert_false probe.definition_list_line?('*value')
    assert_false probe.definition_list_line?('plain text')
  end

  def test_convert_definition_list_block_rewrites_rdoc_lists
    body = "bird::\n* speak\n* fly\n"

    assert_eql "bird:\n- speak\n- fly", probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_returns_nil_for_empty_body
    assert_nil probe.convert_definition_list_block('')
  end

  def test_convert_definition_list_block_trims_trailing_space_from_each_line
    body = "bird::   \n* speak   \n* fly   \n"

    assert_eql "bird:\n- speak\n- fly", probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_returns_nil_for_invalid_definition_lines
    body = "bird::\nplain text\n"

    assert_nil probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_returns_nil_for_bullet_only_lists
    body = "* speak\n* fly\n"

    assert_nil probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_preserves_blank_lines_between_entries
    body = "bird::\n\n* speak\n"

    assert_eql "bird:\n\n- speak", probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_strips_indented_headings_and_bullets
    body = "  bird::\n  *   speak\n"

    assert_eql "bird:\n- speak", probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_returns_nil_for_non_lists
    assert_eql nil, probe.convert_definition_list_block("plain\ntext\n")
  end

  def test_normalize_definition_list_code_blocks_only_rewrites_matching_fences
    markdown = "```\nbird::\n* speak\n```\n\n```\nplain\ntext\n```"

    assert_eql "bird:\n- speak\n\n```\nplain\ntext\n```", probe.normalize_definition_list_code_blocks(markdown)
  end

  def test_normalize_definition_list_code_blocks_rewrites_all_matching_fences
    markdown = "```\nbird::\n* speak\n```\n\n```\nfish::\n* swim\n```"

    assert_eql "bird:\n- speak\n\nfish:\n- swim", probe.normalize_definition_list_code_blocks(markdown)
  end

  def test_normalize_definition_list_code_blocks_preserves_empty_fences
    assert_eql "```\n\n```", probe.normalize_definition_list_code_blocks("```\n\n```")
  end

  def test_markdownify_rewrites_navigation_headings_and_local_links
    html = '<h1>Heading <a href="chapter.html">¶</a> <a href="#top">↑</a></h1><p><a href="guide.html">Guide</a> <a href="/docs/root.md">Root</a> <a href="/docs/root.md?view=full#top">Root Suffix</a> <a href="../files/path/doc.md">File</a> <a href="../classes/Foo.md">Class</a> <a href="../modules/Bar.md">Module</a></p>'

    assert_eql "# Heading\n\n[Guide](guide.md) [Root](docs/root.md) [Root Suffix](docs/root.md?view=full#top) [File](../path/doc.md) [Class](../Foo.md) [Module](../Bar.md)", probe.markdownify(html)
  end

  def test_markdownify_flattens_self_linked_headings
    html = '<h2><a href="#topic">Topic</a></h2>'

    assert_eql '## Topic', probe.markdownify(html)
  end

  def test_markdownify_flattens_self_linked_headings_in_multiline_markdown
    sample = +"Intro\n## [Topic](#topic)\nAfter"

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql "Intro\n## Topic\nAfter", probe.markdownify('<ignored>')
    end
  end

  def test_markdownify_flattens_self_linked_headings_with_extra_heading_spacing
    sample = +'##  [Topic](#topic)'

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql '## Topic', probe.markdownify('<ignored>')
    end
  end

  def test_markdownify_flattens_self_linked_headings_without_trailing_newline
    sample = +'## [Topic](#topic)'

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql '## Topic', probe.markdownify('<ignored>')
    end
  end

  def test_markdownify_flattens_self_linked_headings_with_trailing_spaces
    sample = +"## [Topic](#topic)   "

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql '## Topic', probe.markdownify('<ignored>')
    end
  end

  def test_markdownify_does_not_flatten_self_linked_headings_with_trailing_text
    sample = +'## [Topic](#topic) extra'

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql sample, probe.markdownify('<ignored>')
    end
  end

  def test_markdownify_removes_navigation_links_from_non_top_headings_without_back_links
    html = '<h2>Topic <a href="chapter.html">¶</a></h2>'

    assert_eql '## Topic', probe.markdownify(html)
  end

  def test_markdownify_removes_standalone_back_to_top_links_from_headings
    html = '<h2>Topic <a href="#top">↑</a></h2>'

    assert_eql '## Topic', probe.markdownify(html)
  end

  def test_markdownify_only_rewrites_local_html_links
    html = '<p><a href="Guide.HTML?view=full#top">Guide</a> <a href="http://example.com/doc.html">HTTP</a> <a href="https://example.com/doc.html">HTTPS</a> <a href="mailto:test@example.com">Mail</a> <a href="mailto:report.html">Mail Html</a> <a href="#topic">Anchor</a> <a href="#topic.html">Anchor Html</a></p>'

    assert_eql '[Guide](Guide.md?view=full#top) [HTTP](http://example.com/doc.html) [HTTPS](https://example.com/doc.html) [Mail](mailto:test@example.com) [Mail Html](mailto:report.html) [Anchor](#topic) [Anchor Html](#topic.html)',
               probe.markdownify(html)
  end

  def test_markdownify_normalizes_rdoc_pre_blocks_before_conversion
    html = "<pre>first\n<code>second &amp; third</code></pre>"

    assert_eql "```\nfirst\nsecond & third\n```", probe.markdownify(html)
  end

  def test_markdownify_normalizes_definition_list_pre_blocks_after_conversion
    html = "<pre>bird::\n* speak\n</pre>"

    assert_eql "bird:\n- speak", probe.markdownify(html)
  end

  def test_markdownify_strips_structural_link_segments_with_and_without_parent_prefixes
    html = '<p><a href="files/path/doc.md">File</a> <a href="../files/path/doc.md#part">File Up</a> <a href="classes/Foo.md">Class</a> <a href="../classes/Foo.md?view=1">Class Up</a> <a href="modules/Bar.md">Module</a> <a href="../modules/Bar.md#section-two">Module Up</a></p>'

    assert_eql '[File](path/doc.md) [File Up](../path/doc.md#part) [Class](Foo.md) [Class Up](../Foo.md?view=1) [Module](Bar.md) [Module Up](../Bar.md#section-two)',
               probe.markdownify(html)
  end

  def test_markdownify_bypasses_unknown_tags_while_converting_contents
    assert_eql '**Keep**', probe.markdownify('<custom><strong>Keep</strong></custom>')
  end

  def test_markdownify_runs_unindent_text_on_converted_markdown
    marker_probe_class = Class.new(RDocMarkdownGeneratorProbes::MarkdownProbe) do
      def unindent_text(text)
        "#{super}\nMARKER"
      end
    end
    marker_probe = marker_probe_class.new(nil, generator_options(op_dir: stable_tmpdir('marker-probe')))

    assert_eql "Text\n\n\nMARKER", marker_probe.markdownify('<p>Text</p>')
  end

  def test_markdownify_rewrites_all_rdoc_style_heading_prefixes
    sample = +"=== One\n== Two\n=== Three\n== Four"

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql "### One\n## Two\n### Three\n## Four", probe.markdownify('<ignored>')
    end
  end

  def test_markdownify_strips_leading_whitespace_from_final_output
    sample = +"\nText"

    ReverseMarkdown.stub(:convert, sample) do
      assert_eql 'Text', probe.markdownify('<ignored>')
    end
  end

  def test_debug_is_noop_when_debug_flag_is_disabled
    markdown_probe = probe
    yielded = false
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = nil

    stdout, = capture_io do
      markdown_probe.debug('trace') { yielded = true }
    end

    assert_eql '', stdout
    assert_false yielded
  ensure
    $DEBUG_RDOC = previous
  end

  def test_debug_prints_and_yields_when_debug_flag_is_enabled
    markdown_probe = probe
    yielded = false
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = true

    stdout, = capture_io do
      markdown_probe.debug('trace') { yielded = true }
    end

    assert_eql "[rdoc-markdown] trace\n", stdout
    assert_true yielded
  ensure
    $DEBUG_RDOC = previous
  end

  def test_debug_allows_omitting_the_message
    markdown_probe = probe
    yielded = false
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = true

    stdout, = capture_io do
      markdown_probe.debug { yielded = true }
    end

    assert_eql '', stdout
    assert_true yielded
  ensure
    $DEBUG_RDOC = previous
  end

  def test_debug_does_not_require_a_block
    markdown_probe = probe
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = true

    stdout, = capture_io do
      markdown_probe.debug('trace without block')
    end

    assert_eql "[rdoc-markdown] trace without block\n", stdout
  ensure
    $DEBUG_RDOC = previous
  end

  def test_method_description_returns_described_text_with_method_heading_offset
    method = rdoc_method('run')
    markdown_probe = method_description_probe(describe_return: 'Described body')

    assert_eql 'Described body', markdown_probe.method_description(method, current_class: :current_class)
    assert_eql [[method, {fallback: nil, heading_level_offset: 4}]], markdown_probe.describe_calls
    assert_eql [], markdown_probe.method_link_calls
  end

  def test_method_description_returns_not_documented_when_blank_and_not_alias
    markdown_probe = method_description_probe(describe_return: '')

    assert_eql 'Not documented.', markdown_probe.method_description(rdoc_method('run'), current_class: :current_class)
  end

  def test_method_description_links_alias_target_when_description_is_blank
    alias_target = rdoc_method('key?')
    method = rdoc_method('fetch')
    method.is_alias_for = alias_target
    markdown_probe = method_description_probe(describe_return: '')

    assert_eql 'Alias for: [`key?`](#key?)', markdown_probe.method_description(method, current_class: :current_class)
    assert_eql [[alias_target, :current_class]], markdown_probe.method_link_calls
  end

  def test_method_link_returns_local_anchor_for_methods_on_current_class
    current_class = rdoc_class('Current')
    method = rdoc_method('run', parent: current_class)

    assert_eql '#method-i-run', method_link_probe.method_link(method, current_class: current_class)
  end

  def test_method_link_uses_relative_path_for_methods_on_other_classes
    current_class = rdoc_class('Current')
    target_class = rdoc_class('Target')
    method = rdoc_method('run', parent: target_class)
    markdown_probe = method_link_probe(output_paths: {current_class => 'docs/Current.md', target_class => 'guides/Target.md'})

    assert_eql '../guides/Target.md#method-i-run', markdown_probe.method_link(method, current_class: current_class)
  end

  def test_candidate_with_parent_reductions_strips_dot_prefix_and_walks_parent_levels
    assert_eql ['guide.md'], probe.candidate_with_parent_reductions('./guide.md')
    assert_eql ['../../guide.md', '../guide.md', 'guide.md'], probe.candidate_with_parent_reductions('../../guide.md')
  end

  def test_candidate_with_parent_reductions_rejects_empty_candidates
    assert_eql [], probe.candidate_with_parent_reductions('./')
    assert_eql ['../'], probe.candidate_with_parent_reductions('../')
  end

  def test_resolve_output_path_strips_leading_slashes_and_legacy_prefixes
    markdown_probe = link_probe(known_output_paths: %w[docs/root.md path/doc.md Foo.md Bar.md])

    assert_eql 'docs/root.md', markdown_probe.resolve_output_path('/docs/root.md', Pathname.new('docs'))
    assert_eql 'path/doc.md', markdown_probe.resolve_output_path('/files/path/doc.md', Pathname.new('docs'))
    assert_eql 'Foo.md', markdown_probe.resolve_output_path('classes/Foo.md', Pathname.new('docs'))
    assert_eql 'Bar.md', markdown_probe.resolve_output_path('modules/Bar.md', Pathname.new('docs'))
  end

  def test_resolve_output_path_prefers_exact_match_before_stripping_legacy_prefixes
    markdown_probe = link_probe(known_output_paths: ['files/api.md'])

    assert_eql 'files/api.md', markdown_probe.resolve_output_path('files/api.md', Pathname.new('docs'))
  end

  def test_resolve_output_path_strips_root_segment_and_parent_prefixes_before_matching
    markdown_probe = link_probe(known_output_paths: ['guides/intro.md'])
    current_dir = Pathname.new('docs/api')

    assert_eql 'guides/intro.md', markdown_probe.resolve_output_path('docs-root/guides/intro.md', current_dir)
    assert_eql 'guides/intro.md', markdown_probe.resolve_output_path('../../guides/intro.md', current_dir)
  end

  def test_resolve_output_path_matches_reduced_parent_paths_before_expanding_current_dir
    markdown_probe = link_probe(known_output_paths: ['guides/intro.md'])

    assert_eql 'guides/intro.md', markdown_probe.resolve_output_path('../../guides/intro.md', Pathname.new('docs'))
  end

  def test_resolve_output_path_expands_relative_candidates_against_current_dir
    markdown_probe = link_probe(known_output_paths: ['docs/guides/intro.md'])

    assert_eql 'docs/guides/intro.md', markdown_probe.resolve_output_path('../guides/../guides/intro.md', Pathname.new('docs/api'))
  end

  def test_resolve_output_path_returns_nil_when_nothing_matches
    markdown_probe = link_probe(known_output_paths: ['docs/other.md'])

    assert_nil markdown_probe.resolve_output_path('missing.md', Pathname.new('docs/api'))
  end

  def test_normalize_internal_links_rewrites_known_targets_and_preserves_suffixes
    markdown_probe = link_probe(known_output_paths: ['docs/guide.md', 'guides/intro.md'])
    content = '[Guide](/docs/guide.md#top) [Intro](docs-root/guides/intro.md?view=full) [Anchor](#topic)'

    assert_eql '[Guide](guide.md#top) [Intro](../guides/intro.md?view=full) [Anchor](#topic)',
               markdown_probe.normalize_internal_links(content, current_output_path: 'docs/readme.md')
  end

  def test_normalize_internal_links_skips_external_and_anchor_links
    probe_class = Class.new(RDocMarkdownGeneratorProbes::MarkdownProbe) do
      def resolve_output_path(*)
        raise 'should not resolve external or anchor links'
      end
    end
    markdown_probe = probe_class.new(nil, generator_options(op_dir: stable_tmpdir('external-link-probe')))
    markdown_probe.instance_variable_set(:@known_output_paths, Set['docs/guide.md'])
    content = '[HTTP](http://example.com/doc.md) [HTTPS](https://example.com/doc.md) [Mail](mailto:test@example.com) [Anchor](#topic)'

    assert_eql content, markdown_probe.normalize_internal_links(content, current_output_path: 'docs/readme.md')
  end

  def test_normalize_internal_links_returns_original_markdown_when_known_paths_are_nil
    markdown_probe = probe
    markdown_probe.instance_variable_set(:@known_output_paths, nil)
    content = '[Guide](/docs/guide.md)'

    assert_eql content, markdown_probe.normalize_internal_links(content, current_output_path: 'docs/readme.md')
  end

  def test_normalize_internal_links_returns_original_markdown_when_known_paths_are_empty
    probe_class = Class.new(RDocMarkdownGeneratorProbes::MarkdownProbe) do
      def resolve_output_path(*)
        raise 'should not resolve paths when known paths are empty'
      end
    end
    markdown_probe = probe_class.new(nil, generator_options(op_dir: stable_tmpdir('empty-known-paths-probe')))
    markdown_probe.instance_variable_set(:@known_output_paths, Set.new)
    content = '[Guide](/docs/guide.md)'

    assert_eql content, markdown_probe.normalize_internal_links(content, current_output_path: 'docs/readme.md')
  end

  def test_normalize_internal_links_preserves_bare_query_suffixes
    markdown_probe = link_probe(known_output_paths: ['guides/intro.md'])
    content = '[Intro](docs-root/guides/intro.md?)'

    assert_eql '[Intro](../guides/intro.md?)', markdown_probe.normalize_internal_links(content, current_output_path: 'docs/readme.md')
  end

  def test_normalize_internal_links_keeps_unresolved_targets_unchanged
    markdown_probe = link_probe(known_output_paths: ['docs/guide.md'])
    content = '[Missing](unknown/path.md#part)'

    assert_eql content, markdown_probe.normalize_internal_links(content, current_output_path: 'docs/readme.md')
  end

  def test_describe_uses_fallback_only_for_blank_descriptions
    described = rdoc_class('DescribedTopic', comment: '= Topic')
    blank = rdoc_class('BlankTopic', comment: '   ')
    missing = rdoc_class('MissingTopic')

    assert_eql '### Topic', probe.describe(described, heading_level_offset: 2)
    assert_eql 'Fallback', probe.describe(blank, fallback: 'Fallback')
    assert_eql '', probe.describe(blank)
    assert_eql 'Fallback', probe.describe(missing, fallback: 'Fallback')
    assert_eql '', probe.describe(missing)
  end

  def test_describe_uses_zero_heading_offset_by_default
    described = rdoc_class('DescribedTopic', comment: '== Topic')

    assert_eql '## Topic', probe.describe(described)
  end

  def test_section_description_returns_empty_for_blank_and_shifts_headings
    store = rdoc_store
    described = rdoc_section(comment: '== Section', store: store, section_store: nil)
    blank = rdoc_section(comment: '   ', store: store, section_store: nil)

    assert_eql '#### Section', probe.section_description(described, heading_level_offset: 2)
    assert_eql '', probe.section_description(blank)
  end

  def test_section_description_uses_zero_heading_offset_by_default
    described = rdoc_section(comment: '== Section', section_store: nil)

    assert_eql '## Section', probe.section_description(described)
  end

  def test_section_description_does_not_markdownify_whitespace_only_descriptions
    probe_class = Class.new(RDocMarkdownGeneratorProbes::MarkdownProbe) do
      def markdownify(*)
        raise 'should not markdownify blank section descriptions'
      end
    end
    markdown_probe = probe_class.new(nil, generator_options(op_dir: stable_tmpdir('blank-section-probe')))
    blank = rdoc_section(comment: " \n", section_store: nil)

    assert_eql '', markdown_probe.section_description(blank)
  end

  def test_section_description_html_populates_missing_store_and_uses_comment_fallback
    store = rdoc_store
    store_backed = rdoc_section(comment: 'Body', store: store, section_store: nil)
    fallback = rdoc_section(comment: 'Fallback', parent: RDoc::TopLevel.new('orphan.rb'), section_store: nil)

    assert_eql "\n<p>Body</p>\n", probe.section_description_html(store_backed)
    assert_eql store, store_backed.instance_variable_get(:@store)
    assert_eql 'Fallback', probe.section_description_html(fallback)
  end

  def test_section_description_html_preserves_existing_store
    existing_store = rdoc_store
    section = rdoc_section(comment: 'Body', store: rdoc_store, section_store: existing_store)

    assert_eql "\n<p>Body</p>\n", probe.section_description_html(section)
    assert_eql existing_store, section.instance_variable_get(:@store)
  end

  def test_section_description_html_uses_comments_when_parent_has_no_store
    nil_store_parent = RDoc::TopLevel.new('nil-store.rb')
    nil_parent_store = rdoc_section(comment: 'Body', parent: nil_store_parent, section_store: nil)

    assert_eql 'Body', probe.section_description_html(nil_parent_store)
    assert_nil nil_parent_store.instance_variable_get(:@store)
  end

  def test_section_description_html_returns_empty_for_empty_comment_fallback
    section = rdoc_section(comment: '', parent: RDoc::TopLevel.new('empty.rb'), section_store: nil)

    assert_eql '', probe.section_description_html(section)
  end

  def test_section_description_html_joins_fallback_comment_text
    section = rdoc_section(comment: 'First', parent: RDoc::TopLevel.new('comments.rb'), section_store: nil)
    section.add_comment(RDoc::Comment.new('Second'))

    assert_eql "First\nSecond", probe.section_description_html(section)
  end

  def test_finalize_markdown_normalizes_links_collapses_blank_lines_and_adds_trailing_newline
    markdown_probe = probe
    markdown_probe.instance_variable_set(:@known_output_paths, Set['docs/guide.md'])
    content = "Line 1  \n\n\n[Guide](/docs/guide.md)\n"

    assert_eql "Line 1\n\n[Guide](guide.md)\n", markdown_probe.finalize_markdown(content, current_output_path: 'docs/readme.md')
  end

  def test_finalize_markdown_allows_omitting_current_output_path
    markdown_probe = probe
    markdown_probe.instance_variable_set(:@known_output_paths, Set['docs/guide.md'])

    assert_eql "Line 1\n", markdown_probe.finalize_markdown("Line 1\n")
  end

  def test_finalize_markdown_strips_outer_whitespace_after_normalizing_lines
    assert_eql "Intro\n", probe.finalize_markdown("  Intro\n\n")
  end
end
