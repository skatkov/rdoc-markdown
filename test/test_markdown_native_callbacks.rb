# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"

class TestMarkdownNativeCallbacks < Minitest::Test
  cover "RDoc::Generator::Markdown::Blocks*"
  cover "RDoc::Generator::Markdown::Inline*"
  cover "RDoc::Generator::Markdown::References*"
  cover "RDoc::Generator::Markdown::Formatter*"

  def formatter(options: RDoc::Options.new, relative_name: "guide.rdoc")
    page = rdoc_page(rdoc_store(options: options), relative_name: relative_name, comment: "")
    RDoc::Generator::Markdown::Formatter.new(page, output_object_ids: Set[page.object_id], heading_level_offset: 2)
  end

  def test_paragraph_soft_breaks_are_normalized_throughout_the_paragraph
    visitor = formatter
    document = RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("one\nsecond\r\nthird\n\nfourth"))

    assert_equal "one second third fourth\n\n", document.accept(visitor)
    assert_equal "latin日本語\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("latin\n日本語")).accept(visitor)
    assert_equal "日本語latin\n\n", RDoc::Markup::Document.new(RDoc::Markup::Paragraph.new("日本語\nlatin")).accept(visitor)
  end

  def test_explicit_inline_breaks_do_not_depend_on_trailing_spaces
    assert_equal "first<br>second<br>third", formatter.attributes("first<br>second<br>third")
  end

  def test_class_subheadings_keep_legacy_aliases_even_when_the_title_does_not
    klass = rdoc_class("Sample", comment: "Docs.")
    visitor = RDoc::Generator::Markdown::Formatter.new(klass, output_object_ids: Set[klass.object_id], heading_level_offset: 2)
    document = RDoc::Markup::Document.new(RDoc::Markup::Heading.new(1, "Topic"), RDoc::Markup::Heading.new(2, "Subtopic"))

    assert_equal "### Topic<a id=\"class-sample-topic\"></a>\n\n#### Subtopic<a id=\"class-Sample-label-Subtopic\"></a><a id=\"class-sample-subtopic\"></a>\n\n",
      document.accept(visitor)
  end

  def test_raw_blocks_join_all_parts_and_keep_the_following_paragraph_separate
    visitor = formatter
    document = RDoc::Markup::Document.new(
      RDoc::Markup::Raw.new("<h1>Topic</h1>", "<p>Body", "text</p>"), RDoc::Markup::Paragraph.new("After.")
    )

    assert_equal "### Topic\n\nBody text\n\nAfter.\n\n", document.accept(visitor)
  end

  def test_tables_render_inline_markup_and_escape_every_pipe_in_every_cell
    visitor = formatter
    visitor.start_accepting
    visitor.accept_table(["*Head*", "a|b|c"], [["<code>x|y</code>", "_em_"]], [nil, nil])

    assert_equal "| **Head** | a\\|b\\|c |\n| --- | --- |\n| `x\\|y` | *em* |\n\n", visitor.end_accepting
  end

  def test_nested_blocks_have_only_their_required_list_item_spacing
    visitor = formatter
    document = RDoc::Markup::Document.new(RDoc::Markup::List.new(:NUMBER,
      RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("First.")),
      RDoc::Markup::ListItem.new(nil, RDoc::Markup::Paragraph.new("Second."))))

    assert_equal "1. First.\n2. Second.\n\n", document.accept(visitor)
  end

  def test_urls_preserve_their_scheme_and_map_source_extensions
    visitor = formatter

    assert_equal "[Guide](guide_rdoc.md#topic)", visitor.gen_url("link:guide.rdoc#topic", "Guide")
    assert_equal "[Source](source_rb.md?raw)", visitor.gen_url("link:source.rb?raw", "Source")
    assert_equal "[External](https://example.test/guide.html)", visitor.gen_url("https://example.test/guide.html", "External")
    assert_equal "[Plain](plain.rb.txt)", visitor.gen_url("link:plain.rb.txt", "Plain")
    assert_equal "[WWW](https://www.example.test)", visitor.gen_url("www.example.test", "WWW")
    assert_equal "![](https://example.test/a.jpeg)", visitor.gen_url("https://example.test/a.jpeg", "Image")
    assert_equal "[Local](local.png)", visitor.gen_url("link:local.png", "Local")
    assert_equal "[Guide](../guide_rdoc.md)", formatter(relative_name: "nested/source.rdoc").gen_url("link:guide.rdoc", "Guide")
    assert_equal "[Source](source_RB.md)", visitor.gen_url("link:source.RB", "Source")
    assert_equal "[Source](folder/a:file_rb.md)", visitor.gen_url("link:folder/a:file.rb", "Source")
    assert_equal "[Source](wwwXfile_rb.md)", visitor.gen_url("link:wwwXfile.rb", "Source")
    assert_equal "[Source](file_rb.md)", visitor.gen_url("link:/file.rb", "Source")
    assert_equal "[Source](1local:file_rb.md)", visitor.gen_url("link:1local:file.rb", "Source")
    %w[https://example.test/file.rb HTTP://example.test/file.rdoc //example.test/file.rb www.example.test/file.rb ftp://example.test/file.rb mailto:file.rb #file.rb x:file.rb a1:file.rb a+z:file.rb a-z:file.rb a.z:file.rb].each do |url|
      target = url.start_with?("www.") ? "https://#{url}" : url
      assert_equal "[Source](#{target})", visitor.gen_url(url, "Source")
    end
    %w[png gif jpg jpeg bmp].each do |extension|
      assert_equal "![](http://example.test/image.#{extension})", visitor.gen_url("http://example.test/image.#{extension}", "Image")
    end
  end

  def test_rdoc_labels_keep_both_the_target_and_the_explicit_source_anchor
    visitor = formatter

    assert_equal '<a id="marker"></a>[Note](#target)', visitor.gen_url("rdoc-label:target:marker", "Note")
    assert_equal "[Note](#target)", visitor.gen_url("rdoc-label:target", "Note")
    assert_equal '<a id="marker&quot;&amp;"></a>[Note](#target)', visitor.gen_url('rdoc-label:target:marker"&', "Note")
    assert_equal '<a id="scope:marker"></a>[Note](#target)', visitor.gen_url("rdoc-label:target:scope:marker", "Note")
  end

  def test_link_label_boundaries_suppress_automatic_links_and_escape_visible_text
    visitor = formatter
    assert_false visitor.in_link_label?
    assert_equal "[https://example.test/a\\_b](https://example.test/a_b)", visitor.handle_regexp_HYPERLINK("https://example.test/a_b")
    assert_equal "Label", visitor.inline_nodes(["Label"])
    assert_equal "https://example.test/a\\_b", visitor.handle_regexp_HYPERLINK("https://example.test/a_b")
    assert_equal "Thing\\_Name", visitor.handle_regexp_CROSSREF("Thing_Name")
  end

  def test_automatic_url_registration_supports_each_scheme_and_stops_at_markup_boundaries
    visitor = formatter

    assert_equal "[http://example.test](http://example.test)", visitor.attributes("http://example.test")
    assert_equal "[mailto:a@example.test](mailto:a@example.test)", visitor.attributes("mailto:a@example.test")
    assert_equal "[www.example.test](https://www.example.test)", visitor.attributes("www.example.test")
    assert_equal "[link:guide.rdoc](guide_rdoc.md)", visitor.attributes("link:guide.rdoc")
    assert_equal "[https://example.test](https://example.test) done", visitor.attributes("https://example.test done")
    assert_equal "[https://example.test](https://example.test)\\<text\\>", visitor.attributes("https://example.test<text>")
  end

  def test_unresolved_explicit_references_retain_labels_and_only_warn_when_enabled
    options = RDoc::Options.new
    options.warn_missing_rdoc_ref = false
    visitor = formatter(options: options)

    assert_silent do
      assert_equal "Missing\\_Name", visitor.explicit_reference("Missing_Name")
      assert_equal "A label", visitor.explicit_reference("Missing_Name", "A label")
      assert_equal "Missing\\_Name", visitor.handle_regexp_RDOCLINK("rdoc-ref:Missing_Name")
    end
    options.warn_missing_rdoc_ref = true
    assert_output("guide_rdoc.html: `rdoc-ref:Missing_Name` can't be resolved for `A label`\n") do
      assert_equal "A label", visitor.explicit_reference("Missing_Name", "A label")
    end
  end
end
