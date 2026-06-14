# frozen_string_literal: true

# Optional lookup of method signatures parsed from RBS files.
class RDoc::Generator::Markdown::RbsSignatureIndex
  # Builds a signature index from RBS files included in an RDoc run.
  #
  # @param files [Array<String>] Input files passed to RDoc.
  #
  # @return [RDoc::Generator::Markdown::RbsSignatureIndex] Signature index.
  def self.build(files)
    rbs_files = files.select { |file| File.extname(file) == ".rbs" }
    new(signatures_from(rbs_files))
  end

  # Builds signatures by reusing RBS's own RDoc parser.
  #
  # @param files [Array<String>] RBS files to parse.
  #
  # @return [Hash{Array => String}] Signature lookup keyed by class and method.
  def self.signatures_from(files)
    files.each_with_object({}) do |file, signatures|
      parsed_classes(file).each do |klass|
        klass.method_list.each do |method|
          add_method_signature(signatures, klass: klass, method: method)
        end
      end
    end
  end

  # Parses one RBS file into RDoc class/module objects.
  #
  # @param file [String] RBS file path.
  #
  # @return [Array<RDoc::Context>] Classes and modules parsed from RBS.
  def self.parsed_classes(file)
    store = RDoc::Store.new(RDoc::Options.new)
    top_level = store.add_file(file)
    parser = RDoc::Parser.for(top_level, File.read(file), store.options, nil)
    parser.scan
    store.all_classes_and_modules
  end

  # Adds one RBS-parsed method signature to the lookup.
  #
  # @param signatures [Hash{Array => String}] Signature lookup being populated.
  # @param klass [RDoc::Context] Method owner.
  # @param method [RDoc::AnyMethod] Method parsed by the RBS plugin.
  #
  # @return [void]
  def self.add_method_signature(signatures, klass:, method:)
    signatures[signature_key(klass.full_name, method.singleton, method.name)] = method.param_seq

    return unless method.name == "initialize" && !method.singleton

    signatures[signature_key(klass.full_name, true, "new")] = method.param_seq
  end

  # Builds the signature lookup key for a method.
  #
  # @param class_name [String] RDoc-style class or module name.
  # @param singleton [Boolean] Whether the method is a singleton method.
  # @param method_name [String] Method name.
  #
  # @return [Array<String, Boolean, String>] Signature lookup key.
  def self.signature_key(class_name, singleton, method_name)
    [class_name, singleton, method_name]
  end

  # @param signatures [Hash{Array => String}] Signature lookup.
  def initialize(signatures)
    @signatures = signatures
  end

  # Looks up the RBS signature for an RDoc method.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  #
  # @return [String, nil] RBS method type string when available.
  def signature_for(method)
    @signatures[self.class.signature_key(method.parent.full_name, method.singleton, method.name)]
  end
end
