# frozen_string_literal: true

require_relative "test_helper"

require "commonmarker"
require "nokogiri"
require "rdoc/rdoc"
require "rdoc/markdown"

class TestClassDocs < Minitest::Test
  cover "RDoc::Generator::Markdown#emit_classfiles"
  cover "RDoc::Generator::Markdown#emit_csv_index"
  cover "RDoc::Generator::Markdown#generate"
  cover "RDoc::Generator::Markdown#metadata_reference"
  cover "RDoc::Generator::Markdown#metadata_table_cell"
  cover "RDoc::Generator::Markdown#output_path_for"
  cover "RDoc::Generator::Markdown#setup"

  def generate_from_store(classes, pages: nil, dir: stable_tmpdir("generate-from-store"), root: nil)
    generator = RDoc::Generator::Markdown.new(
      rdoc_store(classes: classes, pages: pages),
      generator_options(op_dir: dir, root: root)
    )
    generator.generate
    dir
  end

  def nest_class(parent, child)
    parent.classes_hash[child.name] = child
    child.parent = parent
  end

  def nest_module(parent, child)
    parent.modules_hash[child.name] = child
    child.parent = parent
  end

  def test_generate_preserves_distinct_repeated_namespaces
    nested = build_rdoc_class(
      full_name: "VendoredPathExpander::Minitest::VendoredPathExpander::PathExpander",
      description: "Nested doc",
      methods: 1
    )
    canonical = build_rdoc_class(
      full_name: "VendoredPathExpander::PathExpander",
      description: "Canonical doc",
      methods: 2
    )

    dir = generate_from_store([nested, canonical])

    assert_includes File.read(File.join(dir, "VendoredPathExpander/PathExpander.md")), "Canonical doc"
    assert_includes File.read(File.join(dir, "VendoredPathExpander/Minitest/VendoredPathExpander/PathExpander.md")), "Nested doc"
    assert_includes index_entries(dir),
      ["VendoredPathExpander::Minitest::VendoredPathExpander::PathExpander", "Class",
        "VendoredPathExpander/Minitest/VendoredPathExpander/PathExpander.md"]
  end

  def test_generate_uses_unique_store_objects
    klass = build_rdoc_class(full_name: "Canonical", description: "Canonical doc")
    options = generator_options(op_dir: stable_tmpdir("unique-store-objects"))
    store = RDoc::Store.new(options)
    klass.store = store
    store.classes_hash[klass.full_name] = klass
    store.classes_hash["Alias"] = klass
    store.complete(:public)

    RDoc::Generator::Markdown.new(store, options).generate

    assert_eql 1, index_entries(options.op_dir).count { |name, type, _path| name == "Canonical" && type == "Class" }
    assert_false File.exist?(File.join(options.op_dir, "Alias.md"))
  end

  def test_generate_renders_metadata_as_table_cells
    store = rdoc_store
    source = rdoc_file(store, name: "a  b—c\\|d.rb")
    klass = RDoc::NormalClass.new("EscapedMetadata", "Struct.new(\n  :value\n) { |member| member }")
    klass.store = store
    klass.full_name = "EscapedMetadata"
    klass.record_location(source)
    klass.add_comment(RDoc::Comment.new("Escaped metadata"), source)

    dir = generate_from_store([klass])
    markdown = File.read(File.join(dir, "EscapedMetadata.md"))
    fragment = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown))
    rows = fragment.css("table tbody tr").map { |row| row.css("td").map(&:text) }

    assert_eql [
      ["Inherits", "Struct.new( :value ) { |member| member }"],
      ["Defined in", "a  b—c\\|d.rb"]
    ], rows
  end

  def test_generate_renders_filename_line_break_inside_one_table_row
    store = rdoc_store
    source = rdoc_file(store, name: "line\nbreak.rb")
    klass = RDoc::NormalClass.new("SingleLineMetadata")
    klass.store = store
    klass.full_name = "SingleLineMetadata"
    klass.record_location(source)

    dir = generate_from_store([klass])
    markdown = File.read(File.join(dir, "SingleLineMetadata.md"))
    table = Nokogiri::HTML.fragment(Commonmarker.to_html(markdown)).at_css("table")

    assert_eql [["Defined in", "line break.rb"]],
      table.css("tbody tr").map { |row| row.css("td").map(&:text) }
  end

  def test_generate_does_not_add_spacing_without_metadata
    mod = RDoc::NormalModule.new("ActiveModel::API")
    mod.add_section("Overview")

    dir = generate_from_store([mod])

    assert_eql <<~MARKDOWN, File.read(File.join(dir, "ActiveModel/API.md"))
      # Module ActiveModel::API<a id="module-activemodel-api"></a>
      ## Overview
    MARKDOWN
  end

  def test_generate_keeps_title_only_sections
    mod = RDoc::NormalModule.new("TitleOnly")
    mod.add_section("Overview")

    dir = generate_from_store([mod])

    assert_includes File.read(File.join(dir, "TitleOnly.md")), "## Overview"
    assert_includes index_entries(dir), ["TitleOnly", "Module", "TitleOnly.md"]
  end

  def test_generate_keeps_source_backed_empty_classes
    real = build_rdoc_class(full_name: "Shell")
    nested = build_rdoc_class(full_name: "Alpha::Another")

    dir = generate_from_store([real, nested])

    assert_true File.exist?(File.join(dir, "Shell.md"))
    assert_true File.exist?(File.join(dir, "Alpha/Another.md"))
    assert_includes index_entries(dir), ["Shell", "Class", "Shell.md"]
    assert_includes index_entries(dir), ["Alpha::Another", "Class", "Alpha/Another.md"]
  end

  def test_generate_skips_non_displayed_classes
    hidden = build_rdoc_class(full_name: "Hidden", description: "Hidden docs")
    hidden.done_documenting = true

    dir = generate_from_store([hidden])

    assert_false File.exist?(File.join(dir, "Hidden.md"))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_skips_empty_classes_without_source_files
    external = RDoc::NormalModule.new("External")

    dir = generate_from_store([external])

    assert_false File.exist?(File.join(dir, "External.md"))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_keeps_source_less_modules_with_content
    included = RDoc::NormalModule.new("IncludedOnly")
    included.add_include(RDoc::Include.new("ExternalMixin", ""))
    omitted = RDoc::NormalClass.new("ExternalBase")
    child = build_rdoc_class(full_name: "Child")
    child.superclass = omitted

    dir = generate_from_store([included, omitted, child])
    markdown = File.read(File.join(dir, "IncludedOnly.md"))
    child_markdown = File.read(File.join(dir, "Child.md"))

    assert_includes markdown, "| **Includes** | ExternalMixin |"
    assert_includes child_markdown, "| **Inherits** | ExternalBase |"
    refute_includes child_markdown, "[ExternalBase]"
    assert_false File.exist?(File.join(dir, "ExternalBase.md"))
  end

  def test_generate_skips_source_less_modules_with_whitespace_only_section_comments
    mod = RDoc::NormalModule.new("WhitespaceOnly")
    mod.add_section(nil, RDoc::Comment.new(" \n\t"))

    dir = generate_from_store([mod])

    assert_false File.exist?(File.join(dir, "WhitespaceOnly.md"))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_keeps_empty_namespace_modules_that_contain_documented_children
    namespace = build_rdoc_module(full_name: "Jekyll")
    child = build_rdoc_class(full_name: "Jekyll::SeoTag", methods: 1)
    nest_class(namespace, child)

    dir = generate_from_store([namespace, child])

    assert_true File.exist?(File.join(dir, "Jekyll.md"))
    assert_true File.exist?(File.join(dir, "Jekyll/SeoTag.md"))
    assert_includes index_entries(dir), ["Jekyll", "Module", "Jekyll.md"]
    assert_includes index_entries(dir), ["Jekyll::SeoTag", "Class", "Jekyll/SeoTag.md"]
  end

  def test_generate_keeps_empty_namespace_modules_that_contain_nested_modules
    namespace = build_rdoc_module(full_name: "Jekyll")
    child = build_rdoc_module(full_name: "Jekyll::SeoTag", methods: 1)
    nest_module(namespace, child)

    dir = generate_from_store([namespace, child])

    assert_true File.exist?(File.join(dir, "Jekyll.md"))
    assert_true File.exist?(File.join(dir, "Jekyll/SeoTag.md"))
    assert_includes index_entries(dir), ["Jekyll", "Module", "Jekyll.md"]
    assert_includes index_entries(dir), ["Jekyll::SeoTag", "Module", "Jekyll/SeoTag.md"]
  end

  def test_generate_keeps_described_namespace_without_api_descendants
    namespace = build_rdoc_module(full_name: "Liquid", description: "Prevent bundler errors")
    child = build_rdoc_class(full_name: "Liquid::Tag")
    nest_class(namespace, child)

    dir = generate_from_store([namespace, child])

    assert_true File.exist?(File.join(dir, "Liquid.md"))
    assert_true File.exist?(File.join(dir, "Liquid/Tag.md"))
    assert_includes index_entries(dir), ["Liquid", "Module", "Liquid.md"]
    assert_includes index_entries(dir), ["Liquid::Tag", "Class", "Liquid/Tag.md"]
  end

  def test_generate_keeps_empty_child_declaration_under_empty_namespace_module
    namespace = build_rdoc_module(full_name: "Ocean")
    child = build_rdoc_class(full_name: "Ocean::Salmon")
    nest_class(namespace, child)

    dir = generate_from_store([namespace, child])

    assert_true File.exist?(File.join(dir, "Ocean.md"))
    assert_true File.exist?(File.join(dir, "Ocean/Salmon.md"))
    assert_includes index_entries(dir), ["Ocean", "Module", "Ocean.md"]
    assert_includes index_entries(dir), ["Ocean::Salmon", "Class", "Ocean/Salmon.md"]
  end

  def test_generate_keeps_empty_child_declaration_under_membered_namespace
    namespace = build_rdoc_module(full_name: "Liquid", description: "Real namespace", methods: 1)
    child = build_rdoc_class(full_name: "Liquid::Tag")
    nest_class(namespace, child)

    dir = generate_from_store([namespace, child])

    assert_true File.exist?(File.join(dir, "Liquid.md"))
    assert_true File.exist?(File.join(dir, "Liquid/Tag.md"))
    assert_includes index_entries(dir), ["Liquid", "Module", "Liquid.md"]
    assert_includes index_entries(dir), ["Liquid::Tag", "Class", "Liquid/Tag.md"]
  end

  def test_generate_keeps_described_namespace_when_empty_child_has_documented_child
    namespace = build_rdoc_module(full_name: "Liquid", description: "Real namespace")
    child = build_rdoc_class(full_name: "Liquid::Tag")
    grandchild = build_rdoc_class(full_name: "Liquid::Tag::Block", methods: 1)
    nest_class(namespace, child)
    nest_class(child, grandchild)

    dir = generate_from_store([namespace, child, grandchild])

    assert_true File.exist?(File.join(dir, "Liquid.md"))
    assert_true File.exist?(File.join(dir, "Liquid/Tag.md"))
    assert_true File.exist?(File.join(dir, "Liquid/Tag/Block.md"))
    assert_includes index_entries(dir), ["Liquid", "Module", "Liquid.md"]
    assert_includes index_entries(dir), ["Liquid::Tag", "Class", "Liquid/Tag.md"]
    assert_includes index_entries(dir), ["Liquid::Tag::Block", "Class", "Liquid/Tag/Block.md"]
  end

  def test_generate_keeps_described_namespace_with_mixed_empty_and_api_children
    namespace = build_rdoc_module(full_name: "Liquid", description: "Real namespace")
    empty_child = build_rdoc_class(full_name: "Liquid::Tag")
    documented_child = build_rdoc_class(full_name: "Liquid::Drop", methods: 1)
    nest_class(namespace, empty_child)
    nest_class(namespace, documented_child)

    dir = generate_from_store([namespace, empty_child, documented_child])

    assert_true File.exist?(File.join(dir, "Liquid.md"))
    assert_true File.exist?(File.join(dir, "Liquid/Tag.md"))
    assert_true File.exist?(File.join(dir, "Liquid/Drop.md"))
    assert_includes index_entries(dir), ["Liquid", "Module", "Liquid.md"]
    assert_includes index_entries(dir), ["Liquid::Tag", "Class", "Liquid/Tag.md"]
    assert_includes index_entries(dir), ["Liquid::Drop", "Class", "Liquid/Drop.md"]
  end

  def test_generate_keeps_documented_namespace_modules_with_documented_children
    namespace = build_rdoc_module(full_name: "Useful", description: "Useful namespace")
    child = build_rdoc_class(full_name: "Useful::Thing", methods: 1)
    nested = build_rdoc_module(full_name: "Useful::Nested", description: "Nested module")
    nest_class(namespace, child)
    nest_module(namespace, nested)

    dir = generate_from_store([namespace, child, nested])

    assert_true File.exist?(File.join(dir, "Useful.md"))
    assert_true File.exist?(File.join(dir, "Useful/Thing.md"))
    assert_true File.exist?(File.join(dir, "Useful/Nested.md"))
    assert_includes index_entries(dir), ["Useful", "Module", "Useful.md"]
    assert_includes index_entries(dir), ["Useful::Thing", "Class", "Useful/Thing.md"]
    assert_includes index_entries(dir), ["Useful::Nested", "Module", "Useful/Nested.md"]
  end

  def test_generate_keeps_described_namespace_with_api_module_descendant
    namespace = build_rdoc_module(full_name: "Useful", description: "Useful namespace")
    nested = build_rdoc_module(full_name: "Useful::Nested", methods: 1)
    nest_module(namespace, nested)

    dir = generate_from_store([namespace, nested])

    assert_true File.exist?(File.join(dir, "Useful.md"))
    assert_true File.exist?(File.join(dir, "Useful/Nested.md"))
    assert_includes index_entries(dir), ["Useful", "Module", "Useful.md"]
    assert_includes index_entries(dir), ["Useful::Nested", "Module", "Useful/Nested.md"]
  end

  def test_generate_keeps_described_namespace_with_only_description_module_descendant
    namespace = build_rdoc_module(full_name: "Useful", description: "Useful namespace")
    nested = build_rdoc_module(full_name: "Useful::Nested", description: "Nested module")
    nest_module(namespace, nested)

    dir = generate_from_store([namespace, nested])

    assert_true File.exist?(File.join(dir, "Useful.md"))
    assert_true File.exist?(File.join(dir, "Useful/Nested.md"))
    assert_includes index_entries(dir), ["Useful", "Module", "Useful.md"]
    assert_includes index_entries(dir), ["Useful::Nested", "Module", "Useful/Nested.md"]
  end

  def test_generate_keeps_classes_with_members_and_nested_children
    parent = build_rdoc_class(full_name: "Jekyll::SeoTag", methods: 1)
    child = build_rdoc_class(full_name: "Jekyll::SeoTag::Drop", methods: 1)
    nest_class(parent, child)

    dir = generate_from_store([parent, child])

    assert_true File.exist?(File.join(dir, "Jekyll/SeoTag.md"))
    assert_true File.exist?(File.join(dir, "Jekyll/SeoTag/Drop.md"))
    assert_includes index_entries(dir), ["Jekyll::SeoTag", "Class", "Jekyll/SeoTag.md"]
    assert_includes index_entries(dir), ["Jekyll::SeoTag::Drop", "Class", "Jekyll/SeoTag/Drop.md"]
  end

  def test_generate_keeps_classes_with_attribute_only_content
    attributed = build_rdoc_class(full_name: "AttributeOnly", attributes: 1)

    dir = generate_from_store([attributed])

    assert_true File.exist?(File.join(dir, "AttributeOnly.md"))
    assert_includes index_entries(dir), ["AttributeOnly", "Class", "AttributeOnly.md"]
  end

  def test_generate_keeps_classes_with_constant_only_content
    constant_only = build_rdoc_class(full_name: "ConstantOnly", constants: 1)

    dir = generate_from_store([constant_only])

    assert_true File.exist?(File.join(dir, "ConstantOnly.md"))
    assert_includes index_entries(dir), ["ConstantOnly", "Class", "ConstantOnly.md"]
  end

  def test_generate_keeps_classes_with_description_only_content
    described = build_rdoc_class(full_name: "DescriptionOnly", description: "Only docs")

    dir = generate_from_store([described])

    assert_true File.exist?(File.join(dir, "DescriptionOnly.md"))
    assert_includes index_entries(dir), ["DescriptionOnly", "Class", "DescriptionOnly.md"]
  end

  def test_generate_handles_nil_descriptions_when_other_content_is_present
    described = build_rdoc_class(full_name: "NilDescription", description: nil, methods: 1)

    dir = generate_from_store([described])

    assert_true File.exist?(File.join(dir, "NilDescription.md"))
    assert_includes index_entries(dir), ["NilDescription", "Class", "NilDescription.md"]
  end

  def test_generate_sorts_classes_by_full_name
    later = build_rdoc_class(full_name: "Zoo::Bee", description: "Bee doc")
    earlier = build_rdoc_class(full_name: "Zoo::Ant", description: "Ant doc")

    dir = generate_from_store([later, earlier])

    class_entries = index_entries(dir).select { |name, type, _path| type == "Class" }

    assert_eql ["Zoo::Ant", "Class", "Zoo/Ant.md"], class_entries.fetch(0)
    assert_eql ["Zoo::Bee", "Class", "Zoo/Bee.md"], class_entries.fetch(1)
  end

  def test_setup_keeps_only_displayed_pages_and_sorts_them_by_base_name
    pages = [
      rdoc_page(relative_name: "zeta.rdoc", comment: "Zeta page"),
      rdoc_page(relative_name: "alpha.rdoc", comment: "Alpha page"),
      rdoc_page(relative_name: "hidden.rdoc", comment: "Hidden page", display: false),
      rdoc_page(relative_name: "binary.rdoc", comment: "Binary page", parser: nil)
    ]

    dir = generate_from_store([], pages: pages)

    assert_true File.exist?(File.join(dir, "alpha_rdoc.md"))
    assert_true File.exist?(File.join(dir, "zeta_rdoc.md"))
    assert_false File.exist?(File.join(dir, "hidden_rdoc.md"))
    assert_false File.exist?(File.join(dir, "binary_rdoc.md"))

    file_entries = index_entries(dir).select { |_name, type, _path| type == "File" }

    assert_eql ["alpha", "File", "alpha_rdoc.md"], file_entries.fetch(0)
    assert_eql ["zeta", "File", "zeta_rdoc.md"], file_entries.fetch(1)
  end

  def test_generate_populates_known_output_paths_for_link_normalization
    klass = build_rdoc_class(
      full_name: "Solo::Thing",
      description: "See {alpha}[alpha_rdoc.html], {canonical}[Solo/Thing.html], and {sibling}[Sibling.html].",
      methods: 1
    )
    sibling = build_rdoc_class(full_name: "Solo::Sibling", description: "Sibling docs")
    pages = [
      rdoc_page(relative_name: "alpha.rdoc", comment: "Alpha page"),
      rdoc_page(relative_name: "hidden.rdoc", comment: "Hidden page", display: false),
      rdoc_page(relative_name: "binary.rdoc", comment: "Binary page", parser: nil)
    ]

    dir = generate_from_store([klass, sibling], pages: pages)

    markdown = File.read(File.join(dir, "Solo/Thing.md"))
    assert_includes markdown, "[alpha](../alpha_rdoc.md)"
    assert_includes markdown, "[canonical](Thing.md)"
    assert_includes markdown, "[sibling](Sibling.md)"
    assert_false File.exist?(File.join(dir, "hidden_rdoc.md"))
    assert_false File.exist?(File.join(dir, "binary_rdoc.md"))
  end

  def test_setup_uses_dot_root_segment_when_root_is_nil
    klass = build_rdoc_class(
      full_name: "DotRoot::Thing",
      description: "See [guide](./guides/rooted.md).",
      methods: 1
    )
    page = rdoc_page(relative_name: "guides/rooted", comment: "Rooted page")

    dir = generate_from_store([klass], pages: [page])

    assert_includes File.read(File.join(dir, "DotRoot/Thing.md")), "[guide](../guides/rooted.md)"
  end

  def test_setup_keeps_crossrefs_to_emitted_pages
    source = rdoc_page(relative_name: "source.rdoc", comment: "{Target}[rdoc-ref:target]")
    target = rdoc_page(relative_name: "target.rdoc", comment: "Target")

    dir = generate_from_store([], pages: [source, target])

    assert_includes File.read(File.join(dir, "source_rdoc.md")), "[Target](target_rdoc.md)"
  end

  def test_setup_uses_root_basename_for_root_segment
    root = File.join(stable_tmpdir("root-path-segment"), "pages")
    klass = build_rdoc_class(
      full_name: "RootSegment::Thing",
      description: "See [guide](pages/guides/rooted.md).",
      methods: 1
    )
    page = rdoc_page(relative_name: "pages/guides/rooted", comment: "Rooted page")

    dir = generate_from_store([klass], pages: [page], root: root)

    assert_includes File.read(File.join(dir, "RootSegment/Thing.md")), "[guide](../guides/rooted.md)"
  end

  def test_emit_csv_index_writes_rows_for_visible_members_and_pages
    klass = build_rdoc_class(full_name: "Csv::Thing", description: "CSV doc")
    klass.add_method(rdoc_method("run", visible: true))
    klass.add_method(rdoc_method("hidden", visible: false))
    klass.add_constant(rdoc_constant("BETA", visible: true))
    klass.add_constant(rdoc_constant("HIDDEN", visible: false))
    klass.add_constant(rdoc_constant("ALPHA", visible: true))
    klass.add_attribute(rdoc_attribute("beta", visible: true))
    klass.add_attribute(rdoc_attribute("hidden", visible: false))
    klass.add_attribute(rdoc_attribute("alpha", visible: true))
    page = rdoc_page(relative_name: "guide.rdoc", comment: "Guide page")
    dir = generate_from_store([klass], pages: [page])

    rows = CSV.parse(File.read(File.join(dir, "index.csv")), headers: true)
    entries = rows.map { |row| [row["name"], row["type"], row["path"]] }

    assert_includes entries, ["Csv::Thing", "Class", "Csv/Thing.md"]
    assert_includes entries, ["Csv::Thing.run", "Method", "Csv/Thing.md#method-i-run"]
    refute_includes entries, ["Csv::Thing.hidden", "Method", "Csv/Thing.md#method-i-hidden"]
    assert_includes entries, ["guide", "File", "guide_rdoc.md"]

    assert_eql [
      ["Csv::Thing.ALPHA", "Constant", "Csv/Thing.md#ALPHA"],
      ["Csv::Thing.BETA", "Constant", "Csv/Thing.md#BETA"]
    ], entries.select { |_name, type, _path| type == "Constant" }

    assert_eql [
      ["Csv::Thing.alpha", "Attribute", "Csv/Thing.md#attribute-i-alpha"],
      ["Csv::Thing.beta", "Attribute", "Csv/Thing.md#attribute-i-beta"]
    ], entries.select { |_name, type, _path| type == "Attribute" }
  end

  def test_generate_rejects_non_string_output_directory_before_writing
    stringified_dir = File.join(stable_tmpdir("invalid-output-stringified"), "stringified")
    invalid_output = Object.new
    invalid_output.define_singleton_method(:to_s) { stringified_dir }
    options = generator_options(op_dir: stable_tmpdir("invalid-output"))
    options.op_dir = invalid_output
    klass = build_rdoc_class(full_name: "InvalidOutput", methods: 1)

    generator = RDoc::Generator::Markdown.new(rdoc_store(classes: [klass]), options)
    error = assert_raises(TypeError) { generator.generate }

    assert_includes error.message, "RDoc markdown output directory must be a String"
    assert_false File.exist?(stringified_dir)
  end

  def test_generate_prints_debug_messages_when_debug_is_enabled
    klass = build_rdoc_class(full_name: "Debug::Thing", description: "Doc")
    dir = stable_tmpdir("debug-output")

    stdout, = with_rdoc_debug(true) do
      capture_io do
        generate_from_store([klass], dir: dir)
      end
    end

    assert_includes stdout, "[rdoc-markdown] Setting things up "
    assert_includes stdout, "[rdoc-markdown] Generate documentation in #{dir}"
    assert_includes stdout, "[rdoc-markdown] Generate pages in #{dir}"
    assert_includes stdout, "[rdoc-markdown] Generate index file in #{dir}"
  end
end
