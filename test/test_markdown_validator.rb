# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/markdown_validator"

class TestMarkdownValidator < Minitest::Test
  def documentation(files)
    root = stable_tmpdir("documentation")
    files.each do |path, content|
      file = File.join(root, path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, content)
    end
    MarkdownValidator.new(root)
  end

  def test_validates_indexed_sections_and_same_document_aliases
    validator = documentation(
      "Node.md" => <<~MARKDOWN,
        # Node

        ### `content()`<a id="method-i-content"></a>
        Returns text.

        ### `inner_text()`<a id="method-i-inner_text"></a>
        Alias for: [`content`](#method-i-content)

        ### `VALUE`<a id="VALUE"></a>
        A constant.

        ### `name` [RW]<a id="attribute-i-name"></a>
        An attribute.
      MARKDOWN
      "guide.markdown" => "# Guide\n\n[Content](Node.md#method-i-content)\n",
      "index.csv" => "name,type,path\nNode,Class,Node.md\nNode.content,Method,Node.md#method-i-content\n" \
        "Node.VALUE,Constant,Node.md#VALUE\nNode.name,Attribute,Node.md#attribute-i-name\nGuide,File,guide.markdown\n"
    )

    assert_eql 2, validator.validate!
  end

  def test_rejects_indexed_method_swallowed_by_an_html_block
    validator = documentation(
      "Node.md" => "# Node\n\n<dl>\n<dd>Copy</dd>\n</dl>\n### `content()`<a id=\"method-i-content\"></a>\n\n",
      "index.csv" => "name,type,path\nNode.content,Method,Node.md#method-i-content\n"
    )

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "missing heading section #method-i-content in Node.md (from index.csv)"
  end

  def test_rejects_alias_to_a_method_swallowed_by_an_html_block
    validator = documentation(
      "Node.md" => <<~MARKDOWN
        # Node

        <dl>
        <dd>Copy</dd>
        </dl>
        ### `content()`<a id="method-i-content"></a>

        ### `inner_text()`<a id="method-i-inner_text"></a>
        Alias for: [`content`](#method-i-content)
      MARKDOWN
    )

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "missing heading section #method-i-content in Node.md (from Node.md)"
  end

  def test_rejects_missing_same_document_fragment
    validator = documentation("Guide.md" => "# Guide\n\n[Missing](#absent)\n")

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "missing anchor #absent in Guide.md (from Guide.md)"
  end

  def test_checks_links_in_raw_html
    validator = documentation("Guide.md" => "# Guide\n\n<dl><dd><a href=\"#absent\">Missing</a></dd></dl>\n")

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "missing anchor #absent in Guide.md"
  end

  def test_ignores_anchor_examples_in_code
    ["```markdown\n# Example<a id=\"example\"></a>\n```", "    # Example<a id=\"example\"></a>", "`<a id=\"example\"></a>`"].each do |example|
      validator = documentation("Guide.md" => "# Guide\n\n#{example}\n\n[Missing](#example)\n")

      error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

      assert_includes error.message, "missing anchor #example in Guide.md"
    end
  end

  def test_rejects_indexed_anchor_outside_a_markdown_heading
    ["<a id=\"method-i-content\"></a>", "<h3 id=\"method-i-content\">content()</h3>"].each do |anchor|
      validator = documentation(
        "Node.md" => "# Node\n\n#{anchor}\n",
        "index.csv" => "name,type,path\nNode.content,Method,Node.md#method-i-content\n"
      )

      error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

      assert_includes error.message, "missing heading section #method-i-content in Node.md"
    end
  end

  def test_indexed_constants_also_require_heading_sections
    validator = documentation(
      "Node.md" => "# Node\n\n<a id=\"VALUE\"></a>\n",
      "index.csv" => "name,type,path\nNode.VALUE,Constant,Node.md#VALUE\n"
    )

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "missing heading section #VALUE in Node.md (from index.csv)"
  end

  def test_accepts_real_heading_slugs_and_standalone_navigation_anchors
    validator = documentation(
      "Guide.md" => <<~MARKDOWN,
        # A *linked* [title](https://example.com) &amp; `code`

        ## Repeated

        ## Repeated

        Setext title
        ------------

        <a id="navigation"></a>

        [Title](#a-linked-title--code)
        [Repeated](#repeated-1)
        [Setext](#setext-title)
        [Navigation](#navigation)
      MARKDOWN
      "index.csv" => "name,type,path\nRepeated,File,Guide.md#repeated-1\n"
    )

    assert_eql 1, validator.validate!
  end

  def test_accepts_escaped_paths_fragments_and_queries
    validator = documentation(
      "docs/Guide.md" => "# Guide\n\n[Other](../Other%20Guide.md?view=full#method-i-content%3D)\n",
      "Other Guide.md" => "# Other\n\n### `content=`<a id=\"method-i-content=\"></a>\n",
      "index.csv" => "name,type,path\nOther,Class,Other%20Guide.md\n"
    )

    assert_eql 2, validator.validate!
  end

  def test_ignores_external_links_and_code_examples
    validator = documentation(
      "Guide.md" => "# Guide\n\n[Web](https://example.com/missing.html) [HTTP](HTTP://example.com) [Mail](mailto:test@example.com)\n\n```markdown\n[Missing](Absent.md#missing)\n```\n"
    )

    assert_eql 1, validator.validate!
  end

  def test_rejects_missing_indexed_document
    validator = documentation(
      "Guide.md" => "# Guide\n",
      "index.csv" => "name,type,path\nMissing,Class,Absent.md\n"
    )

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, 'broken local link in index.csv -> "Absent.md"'
  end

  def test_checks_nested_indexes_relative_to_their_own_directory
    files = {
      "Guide.md" => "# Guide\n",
      "nested/Guide.md" => "# Nested guide\n",
      "nested/index.csv" => "name,type,path\nGuide,File,Guide.md#nested-guide\n"
    }

    assert_eql 2, documentation(files).validate!

    files["nested/index.csv"] = "name,type,path\nMissing,File,Absent.md\n"
    error = assert_raises(MarkdownValidator::ValidationError) { documentation(files).validate! }

    assert_includes error.message, 'broken local link in nested/index.csv -> "Absent.md"'
  end

  def test_rejects_missing_index_path
    ["name,type,path\nMissing,Method,\n", "name,type\nMissing,Method\n"].each do |index|
      validator = documentation("Guide.md" => "# Guide\n", "index.csv" => index)

      error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

      assert_includes error.message, "missing path in index.csv at row 2"
    end
  end

  def test_reports_malformed_csv
    validator = documentation("Guide.md" => "# Guide\n", "index.csv" => "name,type,path\n\"unterminated")

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "invalid index.csv: Unclosed quoted field"
  end

  def test_rejects_links_outside_documentation_root
    workspace = stable_tmpdir("outside-link")
    root = File.join(workspace, "docs")
    FileUtils.mkdir_p(root)
    File.write(File.join(workspace, "outside.md"), "# Outside\n")
    File.write(File.join(root, "Guide.md"), "# Guide\n\n[Outside](../outside.md)\n")

    error = assert_raises(MarkdownValidator::ValidationError) { MarkdownValidator.new(root).validate! }

    assert_includes error.message, 'broken local link in Guide.md -> "../outside.md"'
  end

  def test_rejects_local_html_links
    validator = documentation("Guide.md" => "# Guide\n\n[Legacy](Other.html#topic)\n")

    error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

    assert_includes error.message, "local .html link found in Guide.md"
  end

  def test_rejects_empty_placeholder_anchor
    ["[](#)", "### [](#)", '<a href="#"></a>', '<a href="#" class="anchor" aria-hidden="true" id=""></a>'].each do |link|
      validator = documentation("Guide.md" => "# Guide\n\n#{link}\n")

      error = assert_raises(MarkdownValidator::ValidationError) { validator.validate! }

      assert_includes error.message, "empty anchor link found in Guide.md"
    end
  end

  def test_accepts_operator_headings_with_empty_automatic_slugs
    validator = documentation(
      "Buffer.md" => <<~MARKDOWN,
        # Buffer

        ### `[](*)`<a id="method-i-5B-5D"></a>
        Returns a slice.

        ### `slice(*)`<a id="method-i-slice"></a>
        Alias for: [`[]`](#method-i-5B-5D)
      MARKDOWN
      "index.csv" => "name,type,path\nBuffer.[],Method,Buffer.md#method-i-5B-5D\n"
    )

    assert_eql 1, validator.validate!
  end

  def test_accepts_top_of_document_link
    assert_eql 1, documentation("Guide.md" => "# Guide\n\n[Top](#)\n").validate!
  end

  def test_rejects_empty_documentation_directory
    error = assert_raises(MarkdownValidator::ValidationError) { documentation({}).validate! }

    assert_includes error.message, "No markdown files found"
  end
end
