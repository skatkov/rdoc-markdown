# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestClassDocs < Minitest::Test
  cover 'RDoc::Generator::Markdown#build_class_docs'
  cover 'RDoc::Generator::Markdown#class_content_score'
  cover 'RDoc::Generator::Markdown#class_doc_for'
  cover 'RDoc::Generator::Markdown#display_name'
  cover 'RDoc::Generator::Markdown#emit_classfiles'
  cover 'RDoc::Generator::Markdown#emit_csv_index'
  cover 'RDoc::Generator::Markdown#generate'
  cover 'RDoc::Generator::Markdown#legacy_paths_for'
  cover 'RDoc::Generator::Markdown#normalized_full_name'
  cover 'RDoc::Generator::Markdown#output_path_for'
  cover 'RDoc::Generator::Markdown#setup'
  cover 'RDoc::Generator::Markdown#synthetic_full_name?'

  def generate_from_store(classes, pages: nil, dir: stable_tmpdir('generate-from-store'), root: nil)
    generator = RDoc::Generator::Markdown.new(rdoc_store(classes: classes, pages: pages), generator_options(op_dir: dir, root: root))
    generator.generate
    dir
  end

  def assert_positive_score_beats_zero_score_duplicate(primary)
    duplicate = build_rdoc_class(full_name: "#{primary.full_name}::#{primary.full_name}")

    dir = generate_from_store([primary, duplicate])
    canonical_path = File.join(dir, "#{primary.full_name.tr(':', '/').gsub('//', '/')}.md")

    assert_true File.exist?(canonical_path)
    assert_eql 1, index_entries(dir).count { |entry| entry == [primary.full_name, 'Class', "#{primary.full_name.tr(':', '/')}.md"] }
  end

  def index_entries(dir)
    CSV.parse(File.read(File.join(dir, 'index.csv')), headers: true).map do |row|
      [row['name'], row['type'], row['path']]
    end
  end

  def test_generate_prefers_best_normalized_class_doc_and_writes_legacy_path
    synthetic = build_rdoc_class(
      full_name: 'VendoredPathExpander::Minitest::VendoredPathExpander::PathExpander',
      description: 'Synthetic doc',
      methods: 1
    )
    real = build_rdoc_class(
      full_name: 'VendoredPathExpander::PathExpander',
      description: 'Real doc',
      methods: 2
    )

    dir = generate_from_store([synthetic, real])

    canonical_path = File.join(dir, 'VendoredPathExpander/PathExpander.md')
    legacy_path = File.join(dir, 'VendoredPathExpander/Minitest/VendoredPathExpander/PathExpander.md')

    assert_true File.exist?(canonical_path)
    assert_true File.exist?(legacy_path)
    assert_eql File.read(canonical_path), File.read(legacy_path)
    assert_includes File.read(canonical_path), '# Class VendoredPathExpander::PathExpander'
    assert_includes File.read(canonical_path), 'Real doc'

    entries = index_entries(dir)

    assert_includes entries, ['VendoredPathExpander::PathExpander', 'Class', 'VendoredPathExpander/PathExpander.md']
    assert_eql 1, entries.count { |entry| entry == ['VendoredPathExpander::PathExpander', 'Class', 'VendoredPathExpander/PathExpander.md'] }
    refute(entries.any? { |name, _type, _path| name.include?('VendoredPathExpander::Minitest::VendoredPathExpander') })
  end

  def test_generate_normalizes_synthetic_class_with_multiple_middle_segments
    synthetic = build_rdoc_class(
      full_name: 'Root::One::Two::Root::Thing',
      description: 'Synthetic doc',
      methods: 1
    )
    real = build_rdoc_class(
      full_name: 'Root::Thing',
      description: 'Real doc',
      methods: 2
    )

    dir = generate_from_store([synthetic, real])

    canonical_path = File.join(dir, 'Root/Thing.md')
    legacy_path = File.join(dir, 'Root/One/Two/Root/Thing.md')

    assert_true File.exist?(canonical_path)
    assert_true File.exist?(legacy_path)
    assert_includes File.read(canonical_path), 'Real doc'
    assert_eql File.read(canonical_path), File.read(legacy_path)

    entries = index_entries(dir)
    assert_includes entries, ['Root::Thing', 'Class', 'Root/Thing.md']
    refute(entries.any? { |name, _type, _path| name.include?('Root::One::Two::Root') })
  end

  def test_generate_normalizes_repeated_two_part_class_with_content
    collapsed = build_rdoc_class(full_name: 'Pair::Pair', description: 'Collapsed pair')

    dir = generate_from_store([collapsed])

    canonical_path = File.join(dir, 'Pair.md')
    legacy_path = File.join(dir, 'Pair/Pair.md')

    assert_true File.exist?(canonical_path)
    assert_true File.exist?(legacy_path)
    assert_includes File.read(canonical_path), '# Class Pair'
    assert_includes File.read(canonical_path), 'Collapsed pair'
    assert_eql File.read(canonical_path), File.read(legacy_path)
    assert_includes index_entries(dir), ['Pair', 'Class', 'Pair.md']
  end

  def test_generate_preserves_legacy_path_when_lower_score_duplicate_arrives_later
    real = build_rdoc_class(
      full_name: 'Alpha::Thing',
      description: 'Real doc',
      methods: 2
    )
    synthetic = build_rdoc_class(
      full_name: 'Alpha::Z::Alpha::Thing',
      description: 'Synthetic doc',
      methods: 1
    )

    dir = generate_from_store([real, synthetic])

    canonical_path = File.join(dir, 'Alpha/Thing.md')
    legacy_path = File.join(dir, 'Alpha/Z/Alpha/Thing.md')

    assert_true File.exist?(canonical_path)
    assert_true File.exist?(legacy_path)
    assert_includes File.read(canonical_path), 'Real doc'
    assert_eql File.read(canonical_path), File.read(legacy_path)
  end

  def test_generate_does_not_preserve_legacy_path_from_zero_score_replaced_candidate
    empty = build_rdoc_class(full_name: 'Ghost::Ghost::Thing')
    real = build_rdoc_class(
      full_name: 'Ghost::Thing',
      description: 'Real doc',
      methods: 1
    )

    dir = generate_from_store([empty, real])

    assert_true File.exist?(File.join(dir, 'Ghost/Thing.md'))
    assert_false File.exist?(File.join(dir, 'Ghost/Ghost/Thing.md'))
  end

  def test_generate_does_not_preserve_legacy_path_from_zero_score_later_duplicate
    real = build_rdoc_class(
      full_name: 'Later::Thing',
      description: 'Real doc',
      methods: 1
    )
    empty = build_rdoc_class(full_name: 'Later::Z::Later::Thing')

    dir = generate_from_store([real, empty])

    assert_true File.exist?(File.join(dir, 'Later/Thing.md'))
    assert_false File.exist?(File.join(dir, 'Later/Z/Later/Thing.md'))
    assert_eql 1, index_entries(dir).count { |entry| entry == ['Later::Thing', 'Class', 'Later/Thing.md'] }
  end

  def test_generate_writes_legacy_path_for_positive_score_synthetic_class
    synthetic = build_rdoc_class(
      full_name: 'Solo::Inner::Solo::Thing',
      description: 'Synthetic doc',
      methods: 1
    )

    dir = generate_from_store([synthetic])

    canonical_path = File.join(dir, 'Solo/Thing.md')
    legacy_path = File.join(dir, 'Solo/Inner/Solo/Thing.md')

    assert_true File.exist?(canonical_path)
    assert_true File.exist?(legacy_path)
    assert_eql File.read(canonical_path), File.read(legacy_path)
    assert_includes index_entries(dir), ['Solo::Thing', 'Class', 'Solo/Thing.md']
  end

  def test_generate_skips_zero_score_synthetic_classes
    synthetic = build_rdoc_class(full_name: 'Root::Inner::Root::Thing')

    dir = generate_from_store([synthetic])

    refute File.exist?(File.join(dir, 'Root/Thing.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_skips_zero_score_classes_that_only_collapse_by_normalization
    collapsed = build_rdoc_class(full_name: 'Alpha::Alpha')

    dir = generate_from_store([collapsed])

    assert_false File.exist?(File.join(dir, 'Alpha.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_skips_zero_score_classes_with_synthetic_full_names
    synthetic = build_rdoc_class(full_name: 'Root::Thing::Root')

    dir = generate_from_store([synthetic])

    assert_false File.exist?(File.join(dir, 'Root/Thing/Root.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_keeps_zero_score_real_classes
    real = build_rdoc_class(full_name: 'Shell')
    nested = build_rdoc_class(full_name: 'Alpha::Another')

    dir = generate_from_store([real, nested])

    assert_true File.exist?(File.join(dir, 'Shell.md'))
    assert_true File.exist?(File.join(dir, 'Alpha/Another.md'))
    assert_includes index_entries(dir), ['Shell', 'Class', 'Shell.md']
    assert_includes index_entries(dir), ['Alpha::Another', 'Class', 'Alpha/Another.md']
  end

  def test_generate_keeps_classes_with_attribute_only_content
    attributed = build_rdoc_class(full_name: 'AttributeOnly', attributes: 1)

    dir = generate_from_store([attributed])

    assert_true File.exist?(File.join(dir, 'AttributeOnly.md'))
    assert_includes index_entries(dir), ['AttributeOnly', 'Class', 'AttributeOnly.md']
  end

  def test_attribute_only_score_beats_zero_score_duplicate
    assert_positive_score_beats_zero_score_duplicate(build_rdoc_class(full_name: 'AttributeWinner', attributes: 1))
  end

  def test_attribute_only_score_replaces_earlier_zero_score_duplicate
    duplicate = build_rdoc_class(full_name: 'Attr::A::Attr::Winner')
    primary = build_rdoc_class(full_name: 'Attr::Winner', attributes: 1)

    dir = generate_from_store([duplicate, primary])

    assert_true File.exist?(File.join(dir, 'Attr/Winner.md'))
    assert_false File.exist?(File.join(dir, 'Attr/A/Attr/Winner.md'))
    assert_includes File.read(File.join(dir, 'Attr/Winner.md')), '# Class Attr::Winner'
  end

  def test_generate_keeps_classes_with_constant_only_content
    constant_only = build_rdoc_class(full_name: 'ConstantOnly', constants: 1)

    dir = generate_from_store([constant_only])

    assert_true File.exist?(File.join(dir, 'ConstantOnly.md'))
    assert_includes index_entries(dir), ['ConstantOnly', 'Class', 'ConstantOnly.md']
  end

  def test_constant_only_score_beats_zero_score_duplicate
    assert_positive_score_beats_zero_score_duplicate(build_rdoc_class(full_name: 'ConstantWinner', constants: 1))
  end

  def test_constant_only_score_replaces_earlier_zero_score_duplicate
    duplicate = build_rdoc_class(full_name: 'Const::A::Const::Winner')
    primary = build_rdoc_class(full_name: 'Const::Winner', constants: 1)

    dir = generate_from_store([duplicate, primary])

    assert_true File.exist?(File.join(dir, 'Const/Winner.md'))
    assert_false File.exist?(File.join(dir, 'Const/A/Const/Winner.md'))
    assert_includes File.read(File.join(dir, 'Const/Winner.md')), '# Class Const::Winner'
  end

  def test_generate_keeps_classes_with_description_only_content
    described = build_rdoc_class(full_name: 'DescriptionOnly', description: 'Only docs')

    dir = generate_from_store([described])

    assert_true File.exist?(File.join(dir, 'DescriptionOnly.md'))
    assert_includes index_entries(dir), ['DescriptionOnly', 'Class', 'DescriptionOnly.md']
  end

  def test_generate_handles_nil_descriptions_when_other_content_is_present
    described = build_rdoc_class(full_name: 'NilDescription', description: nil, methods: 1)

    dir = generate_from_store([described])

    assert_true File.exist?(File.join(dir, 'NilDescription.md'))
    assert_includes index_entries(dir), ['NilDescription', 'Class', 'NilDescription.md']
  end

  def test_description_only_score_beats_zero_score_duplicate
    assert_positive_score_beats_zero_score_duplicate(build_rdoc_class(full_name: 'DescriptionWinner', description: 'Only docs'))
  end

  def test_description_only_score_replaces_earlier_zero_score_duplicate
    duplicate = build_rdoc_class(full_name: 'Desc::A::Desc::Winner')
    primary = build_rdoc_class(full_name: 'Desc::Winner', description: 'Only docs')

    dir = generate_from_store([duplicate, primary])

    assert_true File.exist?(File.join(dir, 'Desc/Winner.md'))
    assert_false File.exist?(File.join(dir, 'Desc/A/Desc/Winner.md'))
    assert_includes File.read(File.join(dir, 'Desc/Winner.md')), 'Only docs'
  end

  def test_description_only_score_ties_other_single_signal_scores
    winner = build_rdoc_class(full_name: 'DescTie::Winner', description: 'Method winner', methods: 1)
    challenger = build_rdoc_class(full_name: 'DescTie::Winner::DescTie::Winner', description: 'Description challenger')

    dir = generate_from_store([winner, challenger])

    assert_includes File.read(File.join(dir, 'DescTie/Winner.md')), 'Method winner'
    refute_includes File.read(File.join(dir, 'DescTie/Winner.md')), 'Description challenger'
  end

  def test_description_only_score_ties_method_only_score
    winner = build_rdoc_class(full_name: 'MethodTie::Winner', description: nil, methods: 1)
    challenger = build_rdoc_class(full_name: 'MethodTie::Winner::MethodTie::Winner', description: 'Description challenger')

    dir = generate_from_store([winner, challenger])

    assert_includes index_entries(dir), ['MethodTie::Winner', 'Class', 'MethodTie/Winner.md']
    refute_includes File.read(File.join(dir, 'MethodTie/Winner.md')), 'Description challenger'
  end

  def test_whitespace_only_description_does_not_create_positive_score
    duplicate = build_rdoc_class(full_name: 'Blank::A::Blank::Winner')
    whitespace = build_rdoc_class(full_name: 'Blank::Winner', description: " \n\t")

    dir = generate_from_store([duplicate, whitespace])

    assert_false File.exist?(File.join(dir, 'Blank/Winner.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_sorts_class_docs_by_normalized_display_name
    later_full_name = build_rdoc_class(
      full_name: 'Zoo::M::Zoo::Ant',
      description: 'Ant doc',
      methods: 1
    )
    earlier_full_name = build_rdoc_class(
      full_name: 'Zoo::Bee',
      description: 'Bee doc',
      methods: 1
    )

    dir = generate_from_store([later_full_name, earlier_full_name])

    class_entries = index_entries(dir).select { |name, type, _path| type == 'Class' }

    assert_eql ['Zoo::Ant', 'Class', 'Zoo/Ant.md'], class_entries.fetch(0)
    assert_eql ['Zoo::Bee', 'Class', 'Zoo/Bee.md'], class_entries.fetch(1)
  end

  def test_setup_sorts_store_classes_before_resolving_equal_score_duplicates
    sorted_winner = build_rdoc_class(
      full_name: 'Order::A::Order::Thing',
      description: 'Sorted winner',
      methods: 1
    )
    unsorted_first = build_rdoc_class(
      full_name: 'Order::Thing',
      description: 'Unsorted loser',
      methods: 1
    )

    dir = generate_from_store([unsorted_first, sorted_winner])

    assert_includes File.read(File.join(dir, 'Order/Thing.md')), 'Sorted winner'
    refute_includes File.read(File.join(dir, 'Order/Thing.md')), 'Unsorted loser'
  end

  def test_setup_keeps_only_displayed_pages_and_sorts_them_by_base_name
    pages = [
      rdoc_page(relative_name: 'zeta.rdoc', comment: 'Zeta page'),
      rdoc_page(relative_name: 'alpha.rdoc', comment: 'Alpha page'),
      rdoc_page(relative_name: 'hidden.rdoc', comment: 'Hidden page', display: false),
      rdoc_page(relative_name: 'binary.rdoc', comment: 'Binary page', parser: nil)
    ]

    dir = generate_from_store([], pages: pages)

    assert_true File.exist?(File.join(dir, 'alpha_rdoc.md'))
    assert_true File.exist?(File.join(dir, 'zeta_rdoc.md'))
    assert_false File.exist?(File.join(dir, 'hidden_rdoc.md'))
    assert_false File.exist?(File.join(dir, 'binary_rdoc.md'))

    page_entries = index_entries(dir).select { |_name, type, _path| type == 'Page' }

    assert_eql ['alpha', 'Page', 'alpha_rdoc.md'], page_entries.fetch(0)
    assert_eql ['zeta', 'Page', 'zeta_rdoc.md'], page_entries.fetch(1)
  end

  def test_generate_populates_known_output_paths_for_link_normalization
    klass = build_rdoc_class(
      full_name: 'Solo::Inner::Solo::Thing',
      description: 'See {alpha}[alpha_rdoc.html], {canonical}[Solo/Thing.html], ' \
                   'and {legacy}[Solo/Inner/Solo/Thing.html].',
      methods: 1
    )
    pages = [
      rdoc_page(relative_name: 'alpha.rdoc', comment: 'Alpha page'),
      rdoc_page(relative_name: 'hidden.rdoc', comment: 'Hidden page', display: false),
      rdoc_page(relative_name: 'binary.rdoc', comment: 'Binary page', parser: nil)
    ]

    dir = generate_from_store([klass], pages: pages)

    markdown = File.read(File.join(dir, 'Solo/Thing.md'))
    assert_includes markdown, '[alpha](../alpha_rdoc.md)'
    assert_includes markdown, '[canonical](Thing.md)'
    assert_includes markdown, '[legacy](Inner/Solo/Thing.md)'
    assert_false File.exist?(File.join(dir, 'hidden_rdoc.md'))
    assert_false File.exist?(File.join(dir, 'binary_rdoc.md'))
  end

  def test_setup_uses_dot_root_segment_when_root_is_nil
    klass = build_rdoc_class(
      full_name: 'DotRoot::Thing',
      description: 'See [guide](./guides/rooted.md).',
      methods: 1
    )
    page = rdoc_page(relative_name: 'guides/rooted', comment: 'Rooted page')

    dir = generate_from_store([klass], pages: [page])

    assert_includes File.read(File.join(dir, 'DotRoot/Thing.md')), '[guide](../guides/rooted.md)'
  end

  def test_setup_uses_root_basename_for_root_segment
    root = File.join(stable_tmpdir('root-path-segment'), 'pages')
    klass = build_rdoc_class(
      full_name: 'RootSegment::Thing',
      description: 'See [guide](pages/guides/rooted.md).',
      methods: 1
    )
    page = rdoc_page(relative_name: 'pages/guides/rooted', comment: 'Rooted page')

    dir = generate_from_store([klass], pages: [page], root: root)

    assert_includes File.read(File.join(dir, 'RootSegment/Thing.md')), '[guide](../guides/rooted.md)'
  end

  def test_emit_csv_index_writes_rows_for_visible_members_and_pages
    klass = build_rdoc_class(full_name: 'Csv::Thing', description: 'CSV doc')
    klass.add_method(rdoc_method('run', visible: true))
    klass.add_method(rdoc_method('hidden', visible: false))
    klass.add_constant(rdoc_constant('BETA', visible: true))
    klass.add_constant(rdoc_constant('HIDDEN', visible: false))
    klass.add_constant(rdoc_constant('ALPHA', visible: true))
    klass.add_attribute(rdoc_attribute('beta', visible: true))
    klass.add_attribute(rdoc_attribute('hidden', visible: false))
    klass.add_attribute(rdoc_attribute('alpha', visible: true))
    page = rdoc_page(relative_name: 'guide.rdoc', comment: 'Guide page')
    dir = generate_from_store([klass], pages: [page])

    rows = CSV.parse(File.read(File.join(dir, 'index.csv')), headers: true)
    entries = rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries, ['Csv::Thing', 'Class', 'Csv/Thing.md']
    assert_includes entries, ['Csv::Thing.run', 'Method', 'Csv/Thing.md#method-i-run']
    refute_includes entries, ['Csv::Thing.hidden', 'Method', 'Csv/Thing.md#method-i-hidden']
    assert_includes entries, ['guide', 'Page', 'guide_rdoc.md']

    assert_eql [
      ['Csv::Thing.ALPHA', 'Constant', 'Csv/Thing.md#ALPHA'],
      ['Csv::Thing.BETA', 'Constant', 'Csv/Thing.md#BETA']
    ], entries.select { |_name, type, _path| type == 'Constant' }

    assert_eql [
      ['Csv::Thing.alpha', 'Attribute', 'Csv/Thing.md#attribute-i-alpha'],
      ['Csv::Thing.beta', 'Attribute', 'Csv/Thing.md#attribute-i-beta']
    ], entries.select { |_name, type, _path| type == 'Attribute' }
  end

  def test_generate_prints_debug_messages_when_debug_is_enabled
    klass = build_rdoc_class(full_name: 'Debug::Thing', description: 'Doc')
    dir = stable_tmpdir('debug-output')
    previous = $DEBUG_RDOC
    $DEBUG_RDOC = true

    stdout, = capture_io do
      generate_from_store([klass], dir: dir)
    end

    assert_includes stdout, '[rdoc-markdown] Setting things up '
    assert_includes stdout, "[rdoc-markdown] Generate documentation in #{dir}"
    assert_includes stdout, "[rdoc-markdown] Generate pages in #{dir}"
    assert_includes stdout, "[rdoc-markdown] Generate index file in #{dir}"
  ensure
    $DEBUG_RDOC = previous
  end
end
