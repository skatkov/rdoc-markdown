# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMarkdownHelpers < Minitest::Test
  cover 'RDoc::Generator::Markdown#markdownify'
  cover 'RDoc::Generator::Markdown#describe'
  cover 'RDoc::Generator::Markdown#debug'
  cover 'RDoc::Generator::Markdown#method_description'
  cover 'RDoc::Generator::Markdown#method_link'
  cover 'RDoc::Generator::Markdown#section_description'
  cover 'RDoc::Generator::Markdown#finalize_markdown'
  cover 'RDoc::Generator::Markdown#normalize_internal_links'
  cover 'RDoc::Generator::Markdown#resolve_output_path'
  cover 'RDoc::Generator::Markdown#shift_headings'
  cover 'RDoc::Generator::Markdown#section_description_html'
  cover 'RDoc::Generator::Markdown#normalize_definition_list_code_blocks'
  cover 'RDoc::Generator::Markdown#convert_definition_list_block'
  cover 'RDoc::Generator::Markdown#definition_list_line?'
  cover 'RDoc::Generator::Markdown#normalize_rdoc_pre_blocks'
  cover 'RDoc::Generator::Markdown#unindent_text'

  def generate_markdown(classes: [], pages: [], root: nil)
    dir = stable_tmpdir('generated-markdown')
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
      relative_name: 'guide.rdoc',
      comment: "= Heading\n\n{Guide}[guide.html] {Mail}[mailto:test@example.com] {Anchor}[#topic]\n\n  bird::\n  * speak\n"
    )

    markdown = read_generated('guide_rdoc.md', pages: [page])

    assert_includes markdown, '# Heading'
    assert_includes markdown, '[Guide](guide.md) [Mail](mailto:test@example.com) [Anchor](#topic)'
    assert_includes markdown, "bird:\n- speak"
    assert_equal "\n", markdown[-1]
  end

  def test_invalid_definition_list_blocks_remain_plain_text
    page = rdoc_page(relative_name: 'invalid-definition.rdoc', comment: "= Heading\n\n  bird::\n  plain text\n")

    markdown = read_generated('invalid-definition_rdoc.md', pages: [page])

    assert_includes markdown, "```\nbird::\nplain text\n```"
    refute_includes markdown, '- plain text'
  end

  def test_definition_list_blocks_preserve_blank_lines
    page = rdoc_page(relative_name: 'spaced-definition.rdoc', comment: "= Heading\n\n  bird::\n\n    * speak\n    * fly\n")

    markdown = read_generated('spaced-definition_rdoc.md', pages: [page])

    assert_includes markdown, "bird:\n\n- speak\n- fly"
    refute_includes markdown, "- \n"
    refute_includes markdown, '* speak'
  end

  def test_internal_links_are_rewritten_relative_to_generated_output
    guide = rdoc_page(relative_name: 'guides/intro.rdoc', comment: '= Intro')
    readme = rdoc_page(
      relative_name: 'docs/readme.rdoc',
      comment: '{Intro}[guides/intro_rdoc.html#top] {Missing}[missing/path.html#part]'
    )

    markdown = read_generated('docs/readme_rdoc.md', pages: [guide, readme])

    assert_includes markdown, '[Intro](../guides/intro_rdoc.md#top)'
    assert_includes markdown, '[Missing](missing/path.md#part)'
  end

  def test_class_and_method_descriptions_are_markdownified
    klass = build_rdoc_class(full_name: 'Docs::Thing', description: '= Class Topic')
    klass.add_constant(rdoc_constant('VALUE'))
    method = rdoc_method('run', visible: true, comment: '== Method Topic')
    klass.add_method(method)

    markdown = read_generated('Docs/Thing.md', classes: [klass])

    assert_includes markdown, '# Class Docs::Thing'
    assert_includes markdown, '# Class Topic'
    refute_includes markdown, '## Class Topic'
    assert_includes markdown, '#### `VALUE`'
    assert_includes markdown, 'Not documented.'
    assert_includes markdown, '#### `run()`'
    assert_includes markdown, '###### Method Topic'
  end

  def test_method_aliases_link_to_generated_anchors
    klass = build_rdoc_class(full_name: 'Aliases', description: 'Alias docs')
    target = rdoc_method('key?', visible: true)
    alias_method = rdoc_method('has_key?', visible: true)
    alias_method.is_alias_for = target
    klass.add_method(target)
    klass.add_method(alias_method)

    markdown = read_generated('Aliases.md', classes: [klass])

    assert_includes markdown, 'Alias for: [`key?`](#method-i-key-3F)'
  end

  def test_generated_markdown_collapses_blank_lines_and_strips_line_endings
    page = rdoc_page(relative_name: 'spacing.rdoc', comment: "Line 1  \n\n\nLine 2")

    markdown = read_generated('spacing_rdoc.md', pages: [page])

    refute_includes markdown, "\n\n\n"
    assert_includes markdown, "Line 1\n\nLine 2"
  end

  def test_debug_output_is_observable_through_generation
    page = rdoc_page(relative_name: 'debug.rdoc', comment: 'Debug page')
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = true

    stdout, = capture_io do
      generate_markdown(pages: [page])
    end

    assert_includes stdout, '[rdoc-markdown] Setting things up '
    assert_includes stdout, '[rdoc-markdown] Generate documentation in '
    assert_includes stdout, '[rdoc-markdown] Generate pages in '
    assert_includes stdout, '[rdoc-markdown] Generate index file in '
  ensure
    $DEBUG_RDOC = previous
  end

  def test_debug_output_is_suppressed_by_default
    page = rdoc_page(relative_name: 'quiet.rdoc', comment: 'Quiet page')
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = false

    stdout, = capture_io do
      generate_markdown(pages: [page])
    end

    assert_empty stdout
  ensure
    $DEBUG_RDOC = previous
  end
end
