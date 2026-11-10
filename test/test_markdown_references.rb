# frozen_string_literal: true

require_relative "test_helper"
require "rdoc/markdown"

class TestMarkdownReferences < Minitest::Test
  cover "RDoc::Generator::Markdown::References*"
  cover "RDoc::Generator::Markdown::Inline*"

  def formatter(show_hash: false, hyperlink_all: false)
    options = RDoc::Options.new
    options.show_hash = show_hash
    options.hyperlink_all = hyperlink_all
    store = rdoc_store(options: options)
    file = rdoc_file(store)
    source = file.add_class(RDoc::NormalClass, "Source")
    source.comment = "Source docs."
    source.add_method(rdoc_method("run", comment: "Run."))
    target = file.add_class(RDoc::NormalClass, "Target")
    target.comment = "Target docs."
    target.add_method(rdoc_method("+@", comment: "Plus."))
    target.add_method(rdoc_method("-@", comment: "Minus."))
    target.add_method(rdoc_method("run", comment: "Run."))
    target.add_method(rdoc_method("do_work", comment: "Work."))
    target.add_section("A B", RDoc::Comment.new("Section."))
    hidden = file.add_class(RDoc::NormalClass, "Hidden")
    hidden.comment = "Hidden docs."
    hidden.add_method(rdoc_method("run", comment: "Run."))
    guide = rdoc_page(store, relative_name: "guide.rdoc", comment: "Guide.")
    marked_guide = rdoc_page(store, relative_name: "_guide_.rdoc", comment: "Guide.")
    store.complete(options.visibility)
    RDoc::Generator::Markdown::Formatter.new(source,
      output_object_ids: Set[source.object_id, target.object_id, guide.object_id, marked_guide.object_id], heading_level_offset: 0)
  end

  def test_resolved_targets_distinguish_code_objects_pages_and_explicit_labels
    visitor = formatter

    assert_equal "[`Target`](Target.md)", visitor.reference_link("Target")
    assert_equal "[Look here](Target.md)", visitor.reference_link("Target", label: "Look here")
    assert_equal "[`Target`](Target.md)", visitor.reference_link("Target", label: "Target")
    assert_equal "[guide](guide_rdoc.md)", visitor.reference_link("guide")
    assert_equal "[Guide](guide_rdoc.md)", visitor.reference_link("guide", label: "Guide")
    assert_nil visitor.reference_link("Missing")
    assert_nil visitor.reference_link("Missing@Heading")
    assert_nil visitor.reference_link("")
    assert_equal '[\_guide\_.rdoc](_guide__rdoc.md)', visitor.reference_link("_guide_.rdoc")
    assert_equal "[`Target#do_work`](Target.md#method-i-do_work)", visitor.reference_link("Target#do_work", label: 'Target\\#do\\_work')
  end

  def test_omitted_owners_cannot_be_linked_even_through_their_members
    visitor = formatter

    assert_equal "`Hidden`", visitor.reference_link("Hidden")
    assert_equal "`Hidden#run`", visitor.reference_link("Hidden#run")
    assert_equal "Unlinked", visitor.reference_link("Hidden", label: "Unlinked")
  end

  def test_method_hash_visibility_is_controlled_by_the_documented_option
    assert_equal "[`run`](Source.md#method-i-run)", formatter.reference_link("#run")
    assert_equal "[`#run`](Source.md#method-i-run)", formatter(show_hash: true).reference_link("#run")
  end

  def test_unary_operators_and_encoded_heading_labels_keep_their_meaning
    visitor = formatter

    assert_equal "[`Target#+@`](Target.md#method-i-2B-40)", visitor.reference_link("Target#+@")
    assert_equal "[`Target#-@`](Target.md#method-i-2D-40)", visitor.reference_link("Target#-@")
    assert_equal "[Section](Target.md#a-b)", visitor.reference_link("Target@A+B", label: "Section")
    assert_equal "[Heading](Target.md#class-target-some-heading)", visitor.reference_link("Target@Some+Heading", label: "Heading")
    assert_equal "[Method](Target.md#method-i-run-some-heading)", visitor.reference_link("Target#run@Some+Heading", label: "Method")
    assert_equal "[Local](#some-heading)", visitor.reference_link("@Some+Heading", label: "Local")
    assert_equal "[Some Heading](#some-heading)", visitor.reference_link("@Some+Heading")
    assert_equal "[A B at `Target`](Target.md#a-b)", visitor.reference_link("Target@A+B")
    assert_equal "[A\\_B at `Target`](Target.md#class-target-ab)", visitor.reference_link("Target@A_B")
  end

  def test_inline_code_resolves_valid_references_but_not_arbitrary_lowercase_words
    visitor = formatter

    assert_equal "[`Target`](Target.md)", visitor.attributes("+Target+")
    assert_equal "`run`", visitor.attributes("+run+")
    assert_equal "[`run`](Source.md#method-i-run)", formatter(hyperlink_all: true).attributes("+run+")
    assert_equal "[`run`](Source.md#method-i-run)", formatter(hyperlink_all: true).attributes("run")
    assert_equal "[`run`](Source.md#method-i-run)", visitor.attributes("+#run+")
    assert_equal "[`run`](Source.md#method-i-run)", formatter(hyperlink_all: true).attributes("+#run+")
    assert_equal "[`#run`](Source.md#method-i-run)", formatter(show_hash: true).attributes("+#run+")
    assert_equal "`_guide_.rdoc`", visitor.attributes("+_guide_.rdoc+")
    assert_equal "`Missing`", visitor.attributes("+Missing+")
  end

  def test_inline_code_keeps_file_references_literal_like_main
    visitor = formatter

    assert_equal "`guide.rdoc`", visitor.attributes("+guide.rdoc+")
    assert_equal "`source.rb`", visitor.attributes("<code>source.rb</code>")
    assert_equal "`guide.rdoc@Heading`", visitor.attributes("<code>guide.rdoc@Heading</code>")
    assert_equal "[guide](guide_rdoc.md)", visitor.reference_link("guide")
    assert_equal "[`Target`](Target.md)", visitor.attributes("+Target+")
    assert_equal "[A B at `Target`](Target.md#a-b)", visitor.attributes("<code>Target@A+B</code>")
    assert_equal "`Target`", visitor.attributes('<code>\Target</code>')
    assert_equal '`\Missing`', visitor.attributes('<code>\Missing</code>')
    assert_equal "`prefix Target`", visitor.attributes("<code>prefix Target</code>")
    assert_equal "`prefix Target#run`", visitor.attributes("<code>prefix Target#run</code>")
    assert_equal "`(Target#run)`", visitor.attributes("<code>(Target#run)</code>")
    assert_equal "`Target#run.more`", visitor.attributes("<code>Target#run.more</code>")
    assert_equal "`Target#run followed by text`", visitor.attributes("<code>Target#run followed by text</code>")
    assert_equal "`include Target`", visitor.attributes("<code>include Target</code>")
    assert_equal "`run.more`", formatter(hyperlink_all: true).attributes("<code>run.more</code>")
  end

  def test_markdown_links_resolve_symbolic_targets_without_autolinking_labels
    visitor = formatter

    assert_equal '[custom label](Target.md "title")', visitor.attributes('[custom label](Target "title")')
    assert_equal "[method](Target.md#method-i-run)", visitor.attributes("[method](Target#run)")
    assert_equal "[guide](guide_rdoc.md)", visitor.attributes("[guide](guide)")
    assert_equal "[Hidden](Hidden)", visitor.attributes("[Hidden](Hidden)")
    assert_equal "[missing](Missing)", visitor.attributes("[missing](Missing)")
    assert_equal "![alt](Target)", visitor.attributes("![alt](Target)")
  end

  def test_automatic_reference_exclusions_and_link_labels_never_nest_links
    visitor = formatter
    visitor.options.autolink_excluded_words = ["Target"]
    assert_equal "Target", visitor.handle_regexp_CROSSREF("Target")
    visitor.options.autolink_excluded_words = nil
    assert_equal "[`Target`](Target.md)", visitor.handle_regexp_CROSSREF("Target")
    assert_equal "Foo@example.test", visitor.handle_regexp_CROSSREF("Foo@example.test")
    assert_equal "Target@example.test", visitor.handle_regexp_CROSSREF("Target@example.test")
    assert_equal "Missing\\_Name", visitor.handle_regexp_CROSSREF("Missing_Name")
    assert_equal "[Target](https://example.test)", visitor.attributes("{Target}[https://example.test]")
    assert_equal "[`Target`](https://example.test)", visitor.attributes("{<code>Target</code>}[https://example.test]")
    assert_equal "[Target](https://example.test)", visitor.attributes("{rdoc-ref:Target}[https://example.test]")
    visitor.inline_nodes(["Label"])
    assert_equal '\_label\_', visitor.handle_regexp_RDOCLINK("rdoc-ref:_label_")
  end
end
