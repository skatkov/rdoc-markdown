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
    options = generator_options(op_dir: dir, root: root)
    generator = RDoc::Generator::Markdown.new(
      rdoc_store(classes: classes, pages: pages, options: options),
      options
    )
    generator.generate
    dir
  end

  def nest_class(parent, child)
    parent.classes_hash[child.name] = child
    child.parent = parent
  end

  def test_generate_preserves_distinct_repeated_namespaces
    nested = build_rdoc_class(full_name: "VendoredPathExpander::Minitest::VendoredPathExpander::PathExpander", description: "Nested doc")
    canonical = build_rdoc_class(full_name: "VendoredPathExpander::PathExpander", description: "Canonical doc")

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

  def test_generate_keeps_source_backed_empty_classes
    real = build_rdoc_class(full_name: "Shell", source_backed: true)
    nested = build_rdoc_class(full_name: "Alpha::Another", source_backed: true)

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

  def test_generate_keeps_source_less_modules_with_rendered_content
    included = RDoc::NormalModule.new("IncludedOnly")
    included.add_include(RDoc::Include.new("ExternalMixin", ""))
    described = RDoc::NormalModule.new("DescribedOnly")
    described.add_comment(RDoc::Comment.new("Only docs"), RDoc::TopLevel.new("external.rb"))
    methoded = RDoc::NormalModule.new("MethodOnly")
    methoded.add_method(rdoc_method("run"))
    constant = RDoc::NormalModule.new("ConstantOnly")
    constant.add_constant(rdoc_constant("VALUE"))
    attributed = RDoc::NormalModule.new("AttributeOnly")
    attributed.add_attribute(rdoc_attribute("name"))
    omitted = RDoc::NormalClass.new("ExternalBase")
    child = build_rdoc_class(full_name: "Child", source_backed: true)
    child.superclass = omitted

    dir = generate_from_store([included, described, methoded, constant, attributed, omitted, child])
    markdown = File.read(File.join(dir, "IncludedOnly.md"))
    child_markdown = File.read(File.join(dir, "Child.md"))

    assert_includes markdown, "| **Includes** | ExternalMixin |"
    assert_includes File.read(File.join(dir, "DescribedOnly.md")), "Only docs"
    assert_includes File.read(File.join(dir, "MethodOnly.md")), "#### `run()`"
    assert_includes File.read(File.join(dir, "ConstantOnly.md")), "#### `VALUE`"
    assert_includes File.read(File.join(dir, "AttributeOnly.md")), "#### `name`"
    assert_includes child_markdown, "| **Inherits** | ExternalBase |"
    refute_includes child_markdown, "[ExternalBase]"
    assert_false File.exist?(File.join(dir, "ExternalBase.md"))
  end

  def test_generate_formats_source_less_descriptions_once
    mod = build_rdoc_module(
      full_name: "Documented",
      description: "See {Missing}[rdoc-ref:Missing]."
    )

    stdout, = capture_io { generate_from_store([mod]) }

    assert_eql 1, stdout.scan("can't be resolved").length
  end

  def test_generate_skips_source_less_modules_with_only_hidden_members
    mod = RDoc::NormalModule.new("HiddenOnly")
    mod.add_method(rdoc_method("hidden", visible: false))
    mod.add_constant(rdoc_constant("HIDDEN", visible: false))
    mod.add_attribute(rdoc_attribute("hidden", visible: false))

    dir = generate_from_store([mod])

    assert_false File.exist?(File.join(dir, "HiddenOnly.md"))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_skips_source_less_modules_with_whitespace_only_section_comments
    mod = RDoc::NormalModule.new("WhitespaceOnly")
    mod.add_section(nil, RDoc::Comment.new(" \n\t"))

    dir = generate_from_store([mod])

    assert_false File.exist?(File.join(dir, "WhitespaceOnly.md"))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_keeps_source_backed_namespace_declarations
    namespace = build_rdoc_module(full_name: "Jekyll", source_backed: true)
    child = build_rdoc_class(full_name: "Jekyll::SeoTag", source_backed: true)
    nest_class(namespace, child)

    dir = generate_from_store([namespace, child])

    assert_true File.exist?(File.join(dir, "Jekyll.md"))
    assert_true File.exist?(File.join(dir, "Jekyll/SeoTag.md"))
    assert_includes index_entries(dir), ["Jekyll", "Module", "Jekyll.md"]
    assert_includes index_entries(dir), ["Jekyll::SeoTag", "Class", "Jekyll/SeoTag.md"]
  end

  def test_generate_skips_source_less_ancestors_of_rendered_descendants
    namespace = build_rdoc_module(full_name: "Jekyll")
    child = build_rdoc_class(full_name: "Jekyll::SeoTag")
    grandchild = build_rdoc_class(full_name: "Jekyll::SeoTag::Drop", methods: 1)
    nest_class(namespace, child)
    nest_class(child, grandchild)

    dir = generate_from_store([namespace, child, grandchild])

    assert_false File.exist?(File.join(dir, "Jekyll.md"))
    assert_false File.exist?(File.join(dir, "Jekyll/SeoTag.md"))
    assert_true File.exist?(File.join(dir, "Jekyll/SeoTag/Drop.md"))
    assert_includes index_entries(dir), ["Jekyll::SeoTag::Drop", "Class", "Jekyll/SeoTag/Drop.md"]
  end

  def test_generate_sorts_classes_by_full_name
    later = build_rdoc_class(full_name: "Zoo::Bee", description: "Bee doc")
    earlier = build_rdoc_class(full_name: "Zoo::Ant", description: "Ant doc")

    dir = generate_from_store([later, earlier])

    class_entries = index_entries(dir).select { |name, type, _path| type == "Class" }

    assert_eql ["Zoo::Ant", "Class", "Zoo/Ant.md"], class_entries.fetch(0)
    assert_eql ["Zoo::Bee", "Class", "Zoo/Bee.md"], class_entries.fetch(1)
  end

  def test_setup_keeps_only_documentation_pages_and_sorts_them_by_base_name
    pages = [
      rdoc_page(relative_name: "zeta.rdoc", comment: "Zeta page"),
      rdoc_page(relative_name: "alpha.rdoc", comment: "Alpha page"),
      rdoc_page(relative_name: "hidden.rdoc", comment: "Hidden page", display: false),
      rdoc_page(relative_name: "binary.rdoc", comment: "Binary page", parser: nil),
      rdoc_page(relative_name: "channel.rb.tt", comment: "Channel template")
    ]

    dir = generate_from_store([], pages: pages)

    assert_true File.exist?(File.join(dir, "alpha_rdoc.md"))
    assert_true File.exist?(File.join(dir, "zeta_rdoc.md"))
    assert_false File.exist?(File.join(dir, "hidden_rdoc.md"))
    assert_false File.exist?(File.join(dir, "binary_rdoc.md"))
    assert_false File.exist?(File.join(dir, "channel_rb_tt.md"))

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
