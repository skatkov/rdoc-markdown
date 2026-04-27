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

  GeneratorOptions = Struct.new(:op_dir, :root)
  ToStringOnly = Struct.new(:value) do
    def to_s = value
  end
  DescriptionProbe = Struct.new(:description)
  CommentProbe = Struct.new(:text)
  CommentToSOnly = Struct.new(:value) do
    def to_s = value
  end
  EmptyCommentsProbe = Struct.new(:label) do
    def empty? = true

    def map
      raise 'should not iterate empty comments'
    end
  end
  ParentProbe = Struct.new(:store)
  ParentWithoutStoreProbe = Struct.new(:label)
  RescueSectionProbe = Struct.new(:comments) do
    def description
      raise NoMethodError, 'missing description'
    end
  end
  MissingCommentsSectionProbe = Struct.new(:label) do
    def description
      raise NoMethodError, 'missing description'
    end
  end
  StoreAwareSectionProbe = Struct.new(:description, :parent) do
    def initialize(*args)
      super
      @store = nil
    end
  end
  ParentlessStoreSectionProbe = Struct.new(:description) do
    def initialize(*args)
      super
      @store = nil
    end
  end
  ExistingStoreSectionProbe = Struct.new(:description, :parent) do
    def initialize(*args)
      super
      @store = :existing_store
    end
  end
  NilParentStoreSectionProbe = Struct.new(:description, :parent) do
    def initialize(*args)
      super
      @store = nil
    end

    def instance_variable_set(name, value)
      raise 'should not set @store when parent store is nil' if name == :@store

      super
    end
  end
  NoStoreIvarSectionProbe = Struct.new(:description, :parent)
  AliasTargetProbe = Struct.new(:name)
  AliasMethodProbe = Struct.new(:alias_target) do
    def is_alias_for = alias_target
  end
  MethodOwnerProbe = Struct.new(:label)
  MethodLinkProbe = Struct.new(:parent, :aref)
  MarkdownProbe = Class.new(RDoc::Generator::Markdown) do
    public :markdownify
    public :describe
    public :debug
    public :method_description
    public :method_link
    public :section_description
    public :finalize_markdown
    public :normalize_internal_links
    public :resolve_output_path
    public :candidate_with_parent_reductions
    public :shift_headings
    public :section_description_html
    public :normalize_definition_list_code_blocks
    public :convert_definition_list_block
    public :definition_list_line?
    public :normalize_rdoc_pre_blocks
    public :unindent_text
  end
  MethodDescriptionProbeClass = Class.new(MarkdownProbe) do
    attr_reader :describe_calls, :method_link_calls

    def initialize(*args)
      super
      @describe_calls = []
      @method_link_calls = []
      @describe_return = ''
    end

    def describe_return=(value)
      @describe_return = value
    end

    private

    def describe(code_object, **options)
      @describe_calls << [code_object, options]
      @describe_return
    end

    def method_link(method, current_class:)
      @method_link_calls << [method, current_class]
      "##{method.name}"
    end
  end
  MethodLinkProbeClass = Class.new(MarkdownProbe) do
    def output_paths=(value)
      @output_paths = value
    end

    private

    def output_path_for(code_object)
      @output_paths.fetch(code_object)
    end
  end

  def probe
    MarkdownProbe.new(nil, GeneratorOptions.new(stable_tmpdir('probe'), nil))
  end

  def link_probe(known_output_paths:, root_path_segment: 'docs-root')
    markdown_probe = probe
    markdown_probe.instance_variable_set(:@known_output_paths, Set.new(known_output_paths))
    markdown_probe.instance_variable_set(:@root_path_segment, root_path_segment)
    markdown_probe
  end

  def method_description_probe(describe_return: '')
    markdown_probe = MethodDescriptionProbeClass.new(nil, GeneratorOptions.new(stable_tmpdir('method-description-probe'), nil))
    markdown_probe.describe_return = describe_return
    markdown_probe
  end

  def method_link_probe(output_paths: {})
    markdown_probe = MethodLinkProbeClass.new(nil, GeneratorOptions.new(stable_tmpdir('method-link-probe'), nil))
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
    text = ToStringOnly.new("    one\n  two\n      three\n")

    assert_eql "  one\ntwo\n    three\n", probe.unindent_text(text)
  end

  def test_unindent_text_returns_blank_only_text_unchanged
    text = "\n   \n"

    assert_eql text, probe.unindent_text(text)
  end

  def test_unindent_text_returns_original_object_when_indent_is_zero
    text = ToStringOnly.new("one\n  two\n")

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

  def test_markdownify_accepts_string_like_input_and_only_rewrites_local_html_links
    html = ToStringOnly.new('<p><a href="Guide.HTML?view=full#top">Guide</a> <a href="http://example.com/doc.html">HTTP</a> <a href="https://example.com/doc.html">HTTPS</a> <a href="mailto:test@example.com">Mail</a> <a href="mailto:report.html">Mail Html</a> <a href="#topic">Anchor</a> <a href="#topic.html">Anchor Html</a></p>')

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
    marker_probe_class = Class.new(MarkdownProbe) do
      def unindent_text(text)
        "#{super}\nMARKER"
      end
    end
    marker_probe = marker_probe_class.new(nil, GeneratorOptions.new(stable_tmpdir('marker-probe'), nil))

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
    method = Object.new
    markdown_probe = method_description_probe(describe_return: 'Described body')

    assert_eql 'Described body', markdown_probe.method_description(method, current_class: :current_class)
    assert_eql [[method, {fallback: nil, heading_level_offset: 4}]], markdown_probe.describe_calls
    assert_eql [], markdown_probe.method_link_calls
  end

  def test_method_description_returns_not_documented_when_blank_and_not_alias
    markdown_probe = method_description_probe(describe_return: '')

    assert_eql 'Not documented.', markdown_probe.method_description(Object.new, current_class: :current_class)
  end

  def test_method_description_links_alias_target_when_description_is_blank
    alias_target = AliasTargetProbe.new('key?')
    method = AliasMethodProbe.new(alias_target)
    markdown_probe = method_description_probe(describe_return: '')

    assert_eql 'Alias for: [`key?`](#key?)', markdown_probe.method_description(method, current_class: :current_class)
    assert_eql [[alias_target, :current_class]], markdown_probe.method_link_calls
  end

  def test_method_link_returns_local_anchor_for_methods_on_current_class
    current_class = MethodOwnerProbe.new(:current)
    method = MethodLinkProbe.new(current_class, 'method-i-run')

    assert_eql '#method-i-run', method_link_probe.method_link(method, current_class: current_class)
  end

  def test_method_link_uses_relative_path_for_methods_on_other_classes
    current_class = MethodOwnerProbe.new(:current)
    target_class = MethodOwnerProbe.new(:target)
    method = MethodLinkProbe.new(target_class, 'method-i-run')
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
    probe_class = Class.new(MarkdownProbe) do
      def resolve_output_path(*)
        raise 'should not resolve external or anchor links'
      end
    end
    markdown_probe = probe_class.new(nil, GeneratorOptions.new(stable_tmpdir('external-link-probe'), nil))
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
    probe_class = Class.new(MarkdownProbe) do
      def resolve_output_path(*)
        raise 'should not resolve paths when known paths are empty'
      end
    end
    markdown_probe = probe_class.new(nil, GeneratorOptions.new(stable_tmpdir('empty-known-paths-probe'), nil))
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
    described = DescriptionProbe.new('<h1>Topic</h1>')
    blank = DescriptionProbe.new('   ')
    missing = DescriptionProbe.new(nil)

    assert_eql '### Topic', probe.describe(described, heading_level_offset: 2)
    assert_eql 'Fallback', probe.describe(blank, fallback: 'Fallback')
    assert_eql '', probe.describe(blank)
    assert_eql 'Fallback', probe.describe(missing, fallback: 'Fallback')
    assert_eql '', probe.describe(missing)
  end

  def test_describe_uses_zero_heading_offset_by_default
    described = DescriptionProbe.new('<h2>Topic</h2>')

    assert_eql '## Topic', probe.describe(described)
  end

  def test_section_description_returns_empty_for_blank_and_shifts_headings
    described = StoreAwareSectionProbe.new('<h2>Section</h2>', ParentProbe.new(:store))
    blank = StoreAwareSectionProbe.new('   ', ParentProbe.new(:store))

    assert_eql '#### Section', probe.section_description(described, heading_level_offset: 2)
    assert_eql '', probe.section_description(blank)
  end

  def test_section_description_uses_zero_heading_offset_by_default
    described = StoreAwareSectionProbe.new('<h2>Section</h2>', ParentProbe.new(:store))

    assert_eql '## Section', probe.section_description(described)
  end

  def test_section_description_does_not_markdownify_whitespace_only_descriptions
    probe_class = Class.new(MarkdownProbe) do
      def markdownify(*)
        raise 'should not markdownify blank section descriptions'
      end
    end
    markdown_probe = probe_class.new(nil, GeneratorOptions.new(stable_tmpdir('blank-section-probe'), nil))
    blank = StoreAwareSectionProbe.new(" \n", ParentProbe.new(:store))

    assert_eql '', markdown_probe.section_description(blank)
  end

  def test_section_description_html_populates_missing_store_and_uses_comment_fallback
    store_backed = StoreAwareSectionProbe.new('Body', ParentProbe.new(:parent_store))
    fallback = RescueSectionProbe.new([CommentProbe.new('First'), CommentProbe.new('Second')])

    assert_eql 'Body', probe.section_description_html(store_backed)
    assert_eql :parent_store, store_backed.instance_variable_get(:@store)
    assert_eql "First\nSecond", probe.section_description_html(fallback)
  end

  def test_section_description_html_preserves_existing_store_and_stringifies_descriptions
    section = ExistingStoreSectionProbe.new(ToStringOnly.new('Body'), ParentProbe.new(:parent_store))

    assert_eql 'Body', probe.section_description_html(section)
    assert_eql :existing_store, section.instance_variable_get(:@store)
  end

  def test_section_description_html_does_not_add_store_to_objects_without_store_ivar
    section = NoStoreIvarSectionProbe.new('Body', ParentProbe.new(:parent_store))

    assert_eql 'Body', probe.section_description_html(section)
    assert_false section.instance_variable_defined?(:@store)
  end

  def test_section_description_html_handles_parentless_or_storeless_sections_without_setting_store
    parentless = ParentlessStoreSectionProbe.new('Body')
    storeless_parent = StoreAwareSectionProbe.new('Body', ParentWithoutStoreProbe.new(:parent))
    nil_parent_store = NilParentStoreSectionProbe.new('Body', ParentProbe.new(nil))

    assert_eql 'Body', probe.section_description_html(parentless)
    assert_nil parentless.instance_variable_get(:@store)
    assert_eql 'Body', probe.section_description_html(storeless_parent)
    assert_nil storeless_parent.instance_variable_get(:@store)
    assert_eql 'Body', probe.section_description_html(nil_parent_store)
  end

  def test_section_description_html_returns_empty_for_missing_or_empty_comments
    assert_eql '', probe.section_description_html(RescueSectionProbe.new(EmptyCommentsProbe.new(:empty_comments)))
    assert_eql '', probe.section_description_html(RescueSectionProbe.new(nil))
    assert_eql '', probe.section_description_html(MissingCommentsSectionProbe.new(:missing_comments))
  end

  def test_section_description_html_uses_comment_text_or_to_s_fallback
    fallback = RescueSectionProbe.new([CommentProbe.new('First'), CommentToSOnly.new('Second')])

    assert_eql "First\nSecond", probe.section_description_html(fallback)
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
