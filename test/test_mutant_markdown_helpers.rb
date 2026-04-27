# frozen_string_literal: true

require_relative 'test_helper'

require 'rdoc/rdoc'
require 'rdoc/markdown'
require 'set'

class TestMutantMarkdownHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#markdownify' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#describe' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#section_description' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#finalize_markdown' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#shift_headings' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#section_description_html' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#normalize_definition_list_code_blocks' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#convert_definition_list_block' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#definition_list_line?' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#normalize_rdoc_pre_blocks' if respond_to?(:cover)
  cover 'RDoc::Generator::Markdown#unindent_text' if respond_to?(:cover)

  GeneratorOptions = Struct.new(:op_dir, :root)
  DescriptionProbe = Struct.new(:description)
  CommentProbe = Struct.new(:text)
  ParentProbe = Struct.new(:store)
  RescueSectionProbe = Struct.new(:comments) do
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
  MarkdownProbe = Class.new(RDoc::Generator::Markdown) do
    public :markdownify
    public :describe
    public :section_description
    public :finalize_markdown
    public :shift_headings
    public :section_description_html
    public :normalize_definition_list_code_blocks
    public :convert_definition_list_block
    public :definition_list_line?
    public :normalize_rdoc_pre_blocks
    public :unindent_text
  end

  def probe
    MarkdownProbe.new(nil, GeneratorOptions.new(Dir.mktmpdir, nil))
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

  def test_shift_headings_offsets_and_caps_levels
    markdown = "# One\n##### Two\n"

    assert_eql "### One\n###### Two\n", probe.shift_headings(markdown, 2)
    assert_eql markdown, probe.shift_headings(markdown, 0)
  end

  def test_definition_list_line_detects_allowed_lines
    assert_true probe.definition_list_line?('item::')
    assert_true probe.definition_list_line?('  * value')
    assert_true probe.definition_list_line?('   ')
    assert_false probe.definition_list_line?('plain text')
  end

  def test_convert_definition_list_block_rewrites_rdoc_lists
    body = "bird::\n* speak\n* fly\n"

    assert_eql "bird:\n- speak\n- fly", probe.convert_definition_list_block(body)
  end

  def test_convert_definition_list_block_trims_trailing_space_from_each_line
    body = "bird::   \n* speak   \n* fly   \n"

    assert_eql "bird:\n- speak\n- fly", probe.convert_definition_list_block(body)
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
    html = '<h1>Heading <a href="chapter.html">¶</a> <a href="#top">↑</a></h1><p><a href="guide.html">Guide</a> <a href="/docs/root.md">Root</a> <a href="../files/path/doc.md">File</a> <a href="../classes/Foo.md">Class</a> <a href="../modules/Bar.md">Module</a></p>'

    assert_eql "# Heading\n\n[Guide](guide.md) [Root](docs/root.md) [File](../path/doc.md) [Class](../Foo.md) [Module](../Bar.md)", probe.markdownify(html)
  end

  def test_markdownify_flattens_self_linked_headings
    html = '<h2><a href="#topic">Topic</a></h2>'

    assert_eql '## Topic', probe.markdownify(html)
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

  def test_section_description_html_populates_missing_store_and_uses_comment_fallback
    store_backed = StoreAwareSectionProbe.new('Body', ParentProbe.new(:parent_store))
    fallback = RescueSectionProbe.new([CommentProbe.new('First'), CommentProbe.new('Second')])

    assert_eql 'Body', probe.section_description_html(store_backed)
    assert_eql :parent_store, store_backed.instance_variable_get(:@store)
    assert_eql "First\nSecond", probe.section_description_html(fallback)
  end

  def test_finalize_markdown_normalizes_links_collapses_blank_lines_and_adds_trailing_newline
    markdown_probe = probe
    markdown_probe.instance_variable_set(:@known_output_paths, Set['docs/guide.md'])
    content = "Line 1  \n\n\n[Guide](/docs/guide.md)\n"

    assert_eql "Line 1\n\n[Guide](guide.md)\n", markdown_probe.finalize_markdown(content, current_output_path: 'docs/readme.md')
  end
end
