# frozen_string_literal: true

# Optional lookup of method signatures parsed from RBS files.
class RDoc::Generator::Markdown::RbsSignatureIndex
  # Builds a signature index from RBS files included in an RDoc run.
  #
  # @param files [Array<String>] Input files passed to RDoc.
  # @param base_dir [String, Pathname, nil] Directory where RDoc started.
  # @param store [RDoc::Store, nil] Store containing Ruby code objects and RDoc 8 sidecar signatures.
  #
  # @return [RDoc::Generator::Markdown::RbsSignatureIndex] Signature index.
  def self.build(files, base_dir = nil, store = nil)
    rbs_files = files.select { |file| File.extname(file) == ".rbs" }
    new(signatures_from_store(store).merge(signatures_from(rbs_files, base_dir)))
  end

  # Builds signatures by reusing RBS's own RDoc parser.
  #
  # @param files [Array<String>] RBS files to parse.
  # @param base_dir [String, Pathname, nil] Directory where RDoc started.
  #
  # @return [Hash{Array => Array<String>}] Signature lookup keyed by class and method.
  def self.signatures_from(files, base_dir)
    files.each_with_object({}) do |file, signatures|
      parsed_classes(file, base_dir).each do |klass|
        klass.method_list.each do |method|
          add_method_signature_lines(signatures, klass: klass, method: method, lines: rbs_signature_lines_from_method(method))
        end
      end
    end
  end

  # Builds signatures already merged into an RDoc store.
  #
  # @param store [RDoc::Store, nil] Store containing Ruby code objects and RDoc 8 sidecar signatures.
  #
  # @return [Hash{Array => Array<String>}] Signature lookup keyed by class and method.
  def self.signatures_from_store(store)
    return {} unless store

    store.all_classes_and_modules.each_with_object({}) do |klass, signatures|
      klass.method_list.each do |method|
        add_method_signature_lines(signatures, klass: klass, method: method, lines: store_signature_lines_from_method(method, store))
      end
    end
  end

  # Parses one RBS file into RDoc class/module objects.
  #
  # @param file [String] RBS file path.
  # @param base_dir [String, Pathname, nil] Directory where RDoc started.
  #
  # @return [Array<RDoc::Context>] Classes and modules parsed from RBS.
  def self.parsed_classes(file, base_dir)
    file_path = rbs_file_path(file, base_dir)
    store = RDoc::Store.new(RDoc::Options.new)
    top_level = store.add_file(file_path)
    parser = RDoc::Parser.for(top_level, File.read(file_path), store.options, nil)
    parser.scan
    store.all_classes_and_modules
  end

  # Resolves an RBS file path against the directory RDoc started from.
  # RDoc changes into the output directory before generators run.
  #
  # @param file [String] RBS file path passed to RDoc.
  # @param base_dir [String, Pathname, nil] Directory where RDoc started.
  #
  # @return [String] Absolute or already absolute RBS file path.
  def self.rbs_file_path(file, base_dir)
    Pathname.new(file).expand_path(base_dir).to_s
  end

  # Adds resolved method signature lines to the lookup.
  #
  # @param signatures [Hash{Array => Array<String>}] Signature lookup being populated.
  # @param klass [RDoc::Context] Method owner.
  # @param method [RDoc::AnyMethod] Method object.
  # @param lines [Array<String>] Signature text lines.
  #
  # @return [void]
  def self.add_method_signature_lines(signatures, klass:, method:, lines:)
    return if lines.empty?

    signatures[[klass.full_name, method.singleton, method.name]] = lines

    return unless method.name == "initialize" && !method.singleton

    signatures[[klass.full_name, true, "new"]] = lines
  end

  # Extracts explicit RBS method signature lines from RDoc parser output.
  # RDoc 7 exposes parsed RBS signatures through `param_seq`; RDoc 8 stores
  # them as `type_signature_lines`.
  #
  # @param method [RDoc::AnyMethod] Method parsed by RDoc's RBS parser.
  #
  # @return [Array<String>] RBS signature lines.
  def self.rbs_signature_lines_from_method(method)
    lines = method_type_signature_lines(method)
    lines = method.param_seq if lines.empty?
    nonblank_lines(lines)
  end

  # Extracts RBS method signature lines already merged into a Ruby store.
  # Unlike explicit RBS parser output, ordinary Ruby `param_seq` is not a type
  # signature and must not populate the index.
  #
  # @param method [RDoc::AnyMethod] Method object from the Ruby store.
  # @param store [RDoc::Store] Store with sidecar RBS signatures.
  #
  # @return [Array<String>] RBS signature lines.
  def self.store_signature_lines_from_method(method, store)
    lines = method_type_signature_lines(method)
    lines = store_type_signature_lines(method, store) if lines.empty?
    lines
  end

  # Extracts RDoc 8 inline type signatures from a method.
  #
  # @param method [RDoc::AnyMethod] Method object.
  #
  # @return [Array<String>] Signature lines.
  def self.method_type_signature_lines(method)
    return [] unless method.respond_to?(:type_signature_lines)

    nonblank_lines(method.type_signature_lines)
  end

  # Extracts RDoc 8 sidecar signatures from a store.
  #
  # @param method [RDoc::AnyMethod] Method object.
  # @param store [RDoc::Store, nil] Optional RDoc store with sidecar RBS signatures.
  #
  # @return [Array<String>] Signature lines.
  def self.store_type_signature_lines(method, store)
    return [] unless store.respond_to?(:rbs_signature_for)

    nonblank_lines(store.rbs_signature_for(method))
  end

  # Normalizes a signature-line value to non-blank strings.
  #
  # @param lines [Array<String>, String, nil] Signature text lines.
  #
  # @return [Array<String>] Non-blank signature lines.
  def self.nonblank_lines(lines)
    Array(lines).select { |line| line&.match?(/\S/) }
  end

  # Creates an immutable signature index.
  #
  # @param signatures [Hash{Array => Array<String>}] Signature lookup.
  #
  # @return [void]
  def initialize(signatures)
    @signatures = signatures
  end

  # Looks up the RBS signature lines for an RDoc method.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  #
  # @return [Array<String>] RBS method type lines when available.
  def signature_lines_for(method)
    @signatures.fetch([method.parent.full_name, method.singleton, method.name], [])
  end

  # Checks whether any RBS signatures were parsed.
  #
  # @return [Boolean] True when type signatures are available.
  def any?
    @signatures.any?
  end

  private_class_method \
    :signatures_from,
    :signatures_from_store,
    :parsed_classes,
    :rbs_file_path,
    :add_method_signature_lines,
    :rbs_signature_lines_from_method,
    :store_signature_lines_from_method,
    :method_type_signature_lines,
    :store_type_signature_lines,
    :nonblank_lines
end
