# frozen_string_literal: true

require_relative 'test_helper'

require 'csv'
require 'rdoc/rdoc'
require 'rdoc/markdown'

class TestMutantClassDocs < Minitest::Test
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

  GeneratorOptions = Struct.new(:op_dir, :root)
  ScoreProbe = Class.new(RDoc::Generator::Markdown) do
    public :class_content_score
    public :emit_classfiles
    public :emit_csv_index
    public :normalized_full_name
    public :setup
    public :synthetic_full_name?
  end
  EmitProbe = Class.new(ScoreProbe) do
    attr_reader :finalize_calls

    def initialize(*args)
      super
      @finalize_calls = []
    end

    private

    def finalize_markdown(content, current_output_path: nil)
      @finalize_calls << [content, current_output_path]
      "finalized #{current_output_path}"
    end
  end
  GenerateProbe = Class.new(RDoc::Generator::Markdown) do
    attr_reader :calls

    def initialize(*args)
      super
      @calls = []
    end

    private

    def debug(str = nil)
      @calls << [:debug, str]
    end

    def setup
      @output_dir = Pathname.new('tmp/generated-docs')
      @calls << :setup
    end

    def emit_classfiles
      @calls << :emit_classfiles
    end

    def emit_pagefiles
      @calls << :emit_pagefiles
    end

    def emit_csv_index
      @calls << :emit_csv_index
    end
  end
  HiddenMember = Struct.new(:name) do
    def display? = false
  end
  VisibleMember = Struct.new(:name, :aref) do
    def display? = true
  end
  FakeStore = Struct.new(:classes, :pages) do
    def all_classes_and_modules = classes

    def all_files = pages || []
  end
  FakePage = Struct.new(:relative_name, :base_name, :page_name, :description, :visible) do
    def text? = true

    def display? = visible
  end
  FakeBinaryPage = Struct.new(:relative_name, :base_name, :page_name, :description, :visible) do
    def text? = false

    def display? = visible
  end
  FakeClass = Struct.new(:full_name, :type, :description, :method_list, :constants, :attributes, :aref) do
    include Comparable

    def <=>(other)
      full_name <=> other.full_name
    end

    def each_section
      nil
    end

    def methods_by_type(_section)
      {}
    end
  end

  def generate_from_store(classes, pages: nil)
    dir = stable_tmpdir('generate-from-store')
    generator = RDoc::Generator::Markdown.new(FakeStore.new(classes, pages), GeneratorOptions.new(dir, nil))
    generator.generate
    dir
  end

  def score_probe
    ScoreProbe.new(nil, GeneratorOptions.new(stable_tmpdir('score-probe'), nil))
  end

  def test_setup_without_store_only_prepares_output_directory
    output_dir = File.join(stable_tmpdir('score-probe-output'), 'out')
    probe = ScoreProbe.new(nil, GeneratorOptions.new(output_dir, nil))

    probe.setup

    assert_true Dir.exist?(output_dir)
  end

  def assert_positive_score_beats_zero_score_duplicate(primary)
    duplicate = build_fake_class(full_name: "#{primary.full_name}::#{primary.full_name}")

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

  def build_fake_class(full_name:, description: '', methods: 0, constants: 0, attributes: 0, aref: nil)
    FakeClass.new(
      full_name,
      'class',
      description,
      Array.new(methods) { |index| HiddenMember.new("hidden_#{index}") },
      Array.new(constants) { |index| HiddenMember.new("CONST_#{index}") },
      Array.new(attributes) { |index| HiddenMember.new("attribute_#{index}") },
      aref || "class-#{full_name.tr(':', '-')}"
    )
  end

  def test_class_content_score_counts_each_signal_once
    klass = build_fake_class(
      full_name: 'ScoreSignals',
      description: 'docs',
      methods: 1,
      constants: 1,
      attributes: 1
    )

    assert_eql 4, score_probe.class_content_score(klass)
  end

  def test_class_content_score_ignores_blank_descriptions
    whitespace = build_fake_class(full_name: 'WhitespaceScore', description: " \n\t")
    nil_description = build_fake_class(full_name: 'NilScore', description: nil, methods: 1)

    assert_eql 0, score_probe.class_content_score(whitespace)
    assert_eql 1, score_probe.class_content_score(nil_description)
  end

  def test_normalized_full_name_keeps_non_synthetic_names
    assert_eql 'Shell', score_probe.normalized_full_name('Shell')
    assert_eql 'Ocean::Salmon', score_probe.normalized_full_name('Ocean::Salmon')
  end

  def test_normalized_full_name_collapses_exact_repetition_suffixes
    assert_eql 'Alpha', score_probe.normalized_full_name('Alpha::Alpha')
    assert_eql 'Ocean::Salmon', score_probe.normalized_full_name('Ocean::Salmon::Ocean::Salmon')
  end

  def test_normalized_full_name_collapses_root_repetition_inside_namespaces
    assert_eql 'Ocean::Salmon', score_probe.normalized_full_name('Ocean::Deep::Ocean::Salmon')
    assert_eql 'Ocean::Salmon', score_probe.normalized_full_name('Ocean::Deep::Cold::Ocean::Salmon')
    assert_eql 'VendoredPathExpander::PathExpander',
               score_probe.normalized_full_name('VendoredPathExpander::Minitest::VendoredPathExpander::PathExpander')
  end

  def test_normalized_full_name_collapses_repeated_prefix_segments
    assert_eql 'A::B::C', score_probe.normalized_full_name('A::B::A::B::C')
  end

  def test_synthetic_full_name_detects_repeated_root_segments
    assert_true score_probe.synthetic_full_name?('Root::Thing::Root')
    assert_true score_probe.synthetic_full_name?('Root::Inner::Root::Thing')
    assert_false score_probe.synthetic_full_name?('Root::Thing')
    assert_false score_probe.synthetic_full_name?('Root::Thing::Else')
    assert_false score_probe.synthetic_full_name?('Alpha::Alpha')
  end

  def test_generate_prefers_best_normalized_class_doc_and_writes_legacy_path
    synthetic = build_fake_class(
      full_name: 'VendoredPathExpander::Minitest::VendoredPathExpander::PathExpander',
      description: 'Synthetic doc',
      methods: 1
    )
    real = build_fake_class(
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

  def test_generate_preserves_legacy_path_when_lower_score_duplicate_arrives_later
    real = build_fake_class(
      full_name: 'Alpha::Thing',
      description: 'Real doc',
      methods: 2
    )
    synthetic = build_fake_class(
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
    empty = build_fake_class(full_name: 'Ghost::Ghost::Thing')
    real = build_fake_class(
      full_name: 'Ghost::Thing',
      description: 'Real doc',
      methods: 1
    )

    dir = generate_from_store([empty, real])

    assert_true File.exist?(File.join(dir, 'Ghost/Thing.md'))
    assert_false File.exist?(File.join(dir, 'Ghost/Ghost/Thing.md'))
  end

  def test_generate_does_not_preserve_legacy_path_from_zero_score_later_duplicate
    real = build_fake_class(
      full_name: 'Later::Thing',
      description: 'Real doc',
      methods: 1
    )
    empty = build_fake_class(full_name: 'Later::Z::Later::Thing')

    dir = generate_from_store([real, empty])

    assert_true File.exist?(File.join(dir, 'Later/Thing.md'))
    assert_false File.exist?(File.join(dir, 'Later/Z/Later/Thing.md'))
    assert_eql 1, index_entries(dir).count { |entry| entry == ['Later::Thing', 'Class', 'Later/Thing.md'] }
  end

  def test_generate_writes_legacy_path_for_positive_score_synthetic_class
    synthetic = build_fake_class(
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
    synthetic = build_fake_class(full_name: 'Root::Inner::Root::Thing')

    dir = generate_from_store([synthetic])

    refute File.exist?(File.join(dir, 'Root/Thing.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_skips_zero_score_classes_that_only_collapse_by_normalization
    collapsed = build_fake_class(full_name: 'Alpha::Alpha')

    dir = generate_from_store([collapsed])

    assert_false File.exist?(File.join(dir, 'Alpha.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_skips_zero_score_classes_with_synthetic_full_names
    synthetic = build_fake_class(full_name: 'Root::Thing::Root')

    dir = generate_from_store([synthetic])

    assert_false File.exist?(File.join(dir, 'Root/Thing/Root.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_keeps_zero_score_real_classes
    real = build_fake_class(full_name: 'Shell')

    dir = generate_from_store([real])

    assert_true File.exist?(File.join(dir, 'Shell.md'))
    assert_includes index_entries(dir), ['Shell', 'Class', 'Shell.md']
  end

  def test_generate_keeps_classes_with_attribute_only_content
    attributed = build_fake_class(full_name: 'AttributeOnly', attributes: 1)

    dir = generate_from_store([attributed])

    assert_true File.exist?(File.join(dir, 'AttributeOnly.md'))
    assert_includes index_entries(dir), ['AttributeOnly', 'Class', 'AttributeOnly.md']
  end

  def test_attribute_only_score_beats_zero_score_duplicate
    assert_positive_score_beats_zero_score_duplicate(build_fake_class(full_name: 'AttributeWinner', attributes: 1))
  end

  def test_attribute_only_score_replaces_earlier_zero_score_duplicate
    duplicate = build_fake_class(full_name: 'Attr::A::Attr::Winner')
    primary = build_fake_class(full_name: 'Attr::Winner', attributes: 1)

    dir = generate_from_store([duplicate, primary])

    assert_true File.exist?(File.join(dir, 'Attr/Winner.md'))
    assert_false File.exist?(File.join(dir, 'Attr/A/Attr/Winner.md'))
    assert_includes File.read(File.join(dir, 'Attr/Winner.md')), '# Class Attr::Winner'
  end

  def test_generate_keeps_classes_with_constant_only_content
    constant_only = build_fake_class(full_name: 'ConstantOnly', constants: 1)

    dir = generate_from_store([constant_only])

    assert_true File.exist?(File.join(dir, 'ConstantOnly.md'))
    assert_includes index_entries(dir), ['ConstantOnly', 'Class', 'ConstantOnly.md']
  end

  def test_constant_only_score_beats_zero_score_duplicate
    assert_positive_score_beats_zero_score_duplicate(build_fake_class(full_name: 'ConstantWinner', constants: 1))
  end

  def test_constant_only_score_replaces_earlier_zero_score_duplicate
    duplicate = build_fake_class(full_name: 'Const::A::Const::Winner')
    primary = build_fake_class(full_name: 'Const::Winner', constants: 1)

    dir = generate_from_store([duplicate, primary])

    assert_true File.exist?(File.join(dir, 'Const/Winner.md'))
    assert_false File.exist?(File.join(dir, 'Const/A/Const/Winner.md'))
    assert_includes File.read(File.join(dir, 'Const/Winner.md')), '# Class Const::Winner'
  end

  def test_generate_keeps_classes_with_description_only_content
    described = build_fake_class(full_name: 'DescriptionOnly', description: 'Only docs')

    dir = generate_from_store([described])

    assert_true File.exist?(File.join(dir, 'DescriptionOnly.md'))
    assert_includes index_entries(dir), ['DescriptionOnly', 'Class', 'DescriptionOnly.md']
  end

  def test_generate_handles_nil_descriptions_when_other_content_is_present
    described = build_fake_class(full_name: 'NilDescription', description: nil, methods: 1)

    dir = generate_from_store([described])

    assert_true File.exist?(File.join(dir, 'NilDescription.md'))
    assert_includes index_entries(dir), ['NilDescription', 'Class', 'NilDescription.md']
  end

  def test_description_only_score_beats_zero_score_duplicate
    assert_positive_score_beats_zero_score_duplicate(build_fake_class(full_name: 'DescriptionWinner', description: 'Only docs'))
  end

  def test_description_only_score_replaces_earlier_zero_score_duplicate
    duplicate = build_fake_class(full_name: 'Desc::A::Desc::Winner')
    primary = build_fake_class(full_name: 'Desc::Winner', description: 'Only docs')

    dir = generate_from_store([duplicate, primary])

    assert_true File.exist?(File.join(dir, 'Desc/Winner.md'))
    assert_false File.exist?(File.join(dir, 'Desc/A/Desc/Winner.md'))
    assert_includes File.read(File.join(dir, 'Desc/Winner.md')), 'Only docs'
  end

  def test_description_only_score_ties_other_single_signal_scores
    winner = build_fake_class(full_name: 'DescTie::Winner', description: 'Method winner', methods: 1)
    challenger = build_fake_class(full_name: 'DescTie::Winner::DescTie::Winner', description: 'Description challenger')

    dir = generate_from_store([winner, challenger])

    assert_includes File.read(File.join(dir, 'DescTie/Winner.md')), 'Method winner'
    refute_includes File.read(File.join(dir, 'DescTie/Winner.md')), 'Description challenger'
  end

  def test_whitespace_only_description_does_not_create_positive_score
    duplicate = build_fake_class(full_name: 'Blank::A::Blank::Winner')
    whitespace = build_fake_class(full_name: 'Blank::Winner', description: " \n\t")

    dir = generate_from_store([duplicate, whitespace])

    assert_false File.exist?(File.join(dir, 'Blank/Winner.md'))
    assert_predicate index_entries(dir), :empty?
  end

  def test_generate_sorts_class_docs_by_normalized_display_name
    later_full_name = build_fake_class(
      full_name: 'Zoo::M::Zoo::Ant',
      description: 'Ant doc',
      methods: 1
    )
    earlier_full_name = build_fake_class(
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
    sorted_winner = build_fake_class(
      full_name: 'Order::A::Order::Thing',
      description: 'Sorted winner',
      methods: 1
    )
    unsorted_first = build_fake_class(
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
      FakePage.new('zeta.rdoc', 'zeta', 'zeta', 'Zeta page', true),
      FakePage.new('alpha.rdoc', 'alpha', 'alpha', 'Alpha page', true),
      FakePage.new('hidden.rdoc', 'hidden', 'hidden', 'Hidden page', false),
      FakeBinaryPage.new('binary.rdoc', 'binary', 'binary', 'Binary page', true)
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

  def test_setup_populates_known_output_paths_and_class_indexes
    klass = build_fake_class(
      full_name: 'Solo::Inner::Solo::Thing',
      description: 'Synthetic doc',
      methods: 1
    )
    pages = [
      FakePage.new('alpha.rdoc', 'alpha', 'alpha', 'Alpha page', true),
      FakePage.new('hidden.rdoc', 'hidden', 'hidden', 'Hidden page', false),
      FakeBinaryPage.new('binary.rdoc', 'binary', 'binary', 'Binary page', true)
    ]
    probe = ScoreProbe.new(FakeStore.new([klass], pages), GeneratorOptions.new(stable_tmpdir('known-output-paths'), 'nested/docs-root'))

    probe.setup

    class_docs_by_object_id = probe.instance_variable_get(:@class_docs_by_object_id)
    classes = probe.instance_variable_get(:@classes)
    known_output_paths = probe.instance_variable_get(:@known_output_paths)
    root_path_segment = probe.instance_variable_get(:@root_path_segment)

    assert_eql klass, class_docs_by_object_id.fetch(klass.object_id).fetch(:klass)
    assert_eql [klass], classes
    assert_true known_output_paths.include?('Solo/Thing.md')
    assert_true known_output_paths.include?('Solo/Inner/Solo/Thing.md')
    assert_true known_output_paths.include?('alpha_rdoc.md')
    assert_false known_output_paths.include?('hidden_rdoc.md')
    assert_false known_output_paths.include?('binary_rdoc.md')
    assert_eql 'docs-root', root_path_segment
  end

  def test_emit_classfiles_passes_output_path_to_finalize_markdown
    klass = build_fake_class(full_name: 'Emit::Thing', description: 'Emit doc', methods: 1)
    probe = EmitProbe.new(FakeStore.new([klass], []), GeneratorOptions.new(stable_tmpdir('emit-probe'), nil))

    probe.setup
    probe.emit_classfiles

    assert_eql ['Emit/Thing.md'], probe.finalize_calls.map { |_content, current_output_path| current_output_path }
    assert_eql 'finalized Emit/Thing.md', File.read(File.join(probe.instance_variable_get(:@output_dir), 'Emit/Thing.md'))
  end

  def test_emit_csv_index_respects_custom_output_name
    klass = build_fake_class(full_name: 'Csv::Thing', description: 'CSV doc', methods: 1)
    probe = ScoreProbe.new(FakeStore.new([klass], []), GeneratorOptions.new(stable_tmpdir('emit-csv-name'), nil))

    probe.setup
    probe.emit_csv_index('custom.csv')

    output_dir = probe.instance_variable_get(:@output_dir)
    assert_true File.exist?(File.join(output_dir, 'custom.csv'))
    assert_false File.exist?(File.join(output_dir, 'index.csv'))
  end

  def test_emit_csv_index_writes_rows_for_visible_members_and_pages
    klass = FakeClass.new(
      'Csv::Thing',
      'class',
      'CSV doc',
      [VisibleMember.new('run', 'method-i-run')],
      [VisibleMember.new('BETA', 'BETA'), HiddenMember.new('HIDDEN'), VisibleMember.new('ALPHA', 'ALPHA')],
      [VisibleMember.new('beta', 'attribute-i-beta'), HiddenMember.new('hidden'), VisibleMember.new('alpha', 'attribute-i-alpha')],
      'class-Csv-Thing'
    )
    page = FakePage.new('guide.rdoc', 'guide', 'guide', 'Guide page', true)
    probe = ScoreProbe.new(FakeStore.new([klass], [page]), GeneratorOptions.new(stable_tmpdir('emit-csv-rows'), nil))

    probe.setup
    probe.emit_csv_index('custom.csv')

    rows = CSV.parse(File.read(File.join(probe.instance_variable_get(:@output_dir), 'custom.csv')), headers: true)
    entries = rows.map { |row| [row['name'], row['type'], row['path']] }

    assert_includes entries, ['Csv::Thing', 'Class', 'Csv/Thing.md']
    assert_includes entries, ['Csv::Thing.run', 'Method', 'Csv/Thing.md#method-i-run']
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

  def test_generate_runs_setup_then_emits_files_and_index_with_debug_messages
    probe = GenerateProbe.new(nil, GeneratorOptions.new(stable_tmpdir('generate-probe'), nil))

    probe.generate

    assert_eql [
      [:debug, 'Setting things up '],
      :setup,
      [:debug, 'Generate documentation in tmp/generated-docs'],
      :emit_classfiles,
      [:debug, 'Generate pages in tmp/generated-docs'],
      :emit_pagefiles,
      [:debug, 'Generate index file in tmp/generated-docs'],
      :emit_csv_index
    ], probe.calls
  end

  def test_setup_uses_dot_root_segment_when_root_is_nil
    klass = build_fake_class(full_name: 'NilRoot::Thing', description: 'Doc', methods: 1)
    probe = ScoreProbe.new(FakeStore.new([klass], []), GeneratorOptions.new(stable_tmpdir('nil-root-probe'), nil))

    probe.setup

    assert_eql '.', probe.instance_variable_get(:@root_path_segment)
  end
end
