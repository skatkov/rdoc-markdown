# frozen_string_literal: true

require "erb"
require "reverse_markdown"
require "csv"
require "fileutils"
require "optparse"

# Generates Markdown output and a CSV search index from an RDoc store.
class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  require_relative "markdown/conversion"
  require_relative "markdown/crossref"
  require_relative "markdown/descriptions"
  require_relative "markdown/index"
  require_relative "markdown/paths"
  require_relative "markdown/selection"
  require_relative "markdown/signatures"

  include Conversion
  include Descriptions
  include Index
  include Paths
  include Signatures

  # Directory containing ERB templates.
  TEMPLATE_DIR = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "templates"))

  # Supported reverse_markdown unknown-tag modes.
  MARKDOWN_UNKNOWN_TAGS = %i[pass_through drop bypass raise].freeze

  # Prepared objects and lookup tables used during one generation run.
  GenerationState = Data.define(
    :output_dir,
    :classes,
    :pages,
    :class_output_paths,
    :markdown_output_object_ids,
    :known_output_paths,
    :root_path_segment
  )

  # Validated dependencies shared across generation phases.
  Configuration = Data.define(:store, :options, :source_dir, :markdown_unknown_tags)

  # Adds rdoc-markdown generator configuration to RDoc's option object.
  module OptionsExtension
    # Initializes markdown generator options alongside RDoc's built-in options.
    #
    # @return [void]
    def init_ivars
      super
      @markdown_unknown_tags = :pass_through
    end

    # Loads markdown generator options from serialized RDoc options.
    #
    # @param map [Psych::Coder] Serialized RDoc options.
    #
    # @return [void]
    def init_with(map)
      super
      @markdown_unknown_tags = map["markdown_unknown_tags"] if map.map.key?("markdown_unknown_tags")
    end

    # Applies markdown generator options from a loaded .rdoc_options hash.
    #
    # @param map [Hash] Loaded RDoc options.
    #
    # @return [void]
    def override(map)
      super
      @markdown_unknown_tags = map.fetch("markdown_unknown_tags") if map.key?("markdown_unknown_tags")
    end
  end

  # Registers markdown generator-specific RDoc options.
  #
  # @param rdoc_options [RDoc::Options] RDoc options object.
  #
  # @return [void]
  def self.setup_options(rdoc_options)
    rdoc_options.option_parser.on(
      "--markdown-unknown-tags=MODE",
      "How to handle unknown HTML tags: #{MARKDOWN_UNKNOWN_TAGS.join(", ")}."
    ) do |value|
      rdoc_options.markdown_unknown_tags = value.to_sym
    end
  end

  # Validates the configured reverse_markdown unknown-tag mode.
  #
  # @param value [Symbol] Unknown-tag mode.
  #
  # @return [Symbol] Validated unknown-tag mode.
  def self.validate_markdown_unknown_tags(value)
    return value if MARKDOWN_UNKNOWN_TAGS.include?(value)

    expected = MARKDOWN_UNKNOWN_TAGS.map { |mode| ":#{mode}" }.join(", ")
    raise OptionParser::InvalidArgument,
      "invalid markdown_unknown_tags: #{value.inspect} (expected one of: #{expected})"
  end

  # Source store for generated content.
  #
  # @return [RDoc::Store]
  def store
    configuration.store
  end

  # Classes and modules selected for output.
  #
  # @return [Array<RDoc::Context>, nil]
  def classes
    generation_state&.classes
  end

  # Text files selected for output.
  #
  # @return [Array<RDoc::TopLevel>, nil]
  def pages
    generation_state&.pages
  end

  # Creates a generator for an RDoc store and options.
  #
  # @param store [RDoc::Store] Source documentation store.
  # @param rdoc_options [RDoc::Options] Generator options.
  def initialize(store, rdoc_options)
    @configuration = Configuration.new(
      store: store,
      options: rdoc_options,
      source_dir: File.expand_path(rdoc_options.root.to_s),
      markdown_unknown_tags: self.class.validate_markdown_unknown_tags(rdoc_options.markdown_unknown_tags)
    )
  end

  # Writes class files, page files, and the search index.
  #
  # @return [void]
  def generate
    debug("Setting things up ")
    setup

    debug("Generate documentation in #{output_dir}")
    emit_classfiles

    debug("Generate pages in #{output_dir}")
    emit_pagefiles

    debug("Generate index file in #{output_dir}")
    emit_csv_index
  end

  private

  attr_reader :configuration, :generation_state

  # Returns the RDoc options used for this run.
  #
  # @return [RDoc::Options] Generator options.
  def options
    configuration.options
  end

  # Returns the absolute documentation source directory.
  #
  # @return [String] Source directory.
  def source_dir
    configuration.source_dir
  end

  # Returns the validated unknown-tag conversion mode.
  #
  # @return [Symbol] Unknown-tag mode.
  def markdown_unknown_tags
    configuration.markdown_unknown_tags
  end

  # Prints a message when RDoc debug output is enabled.
  #
  # @param str [String] Message to print.
  #
  # @return [void]
  def debug(str)
    # RDoc exposes --debug through this global and does not mirror it on options.
    # standard:disable Style/GlobalVars
    return unless $DEBUG_RDOC
    # standard:enable Style/GlobalVars

    puts "[rdoc-markdown] #{str}"
  end

  # Writes one Markdown file per selected class or module.
  #
  # @return [void]
  def emit_classfiles
    template_content = File.read(File.join(TEMPLATE_DIR, "classfile.md.erb"))
    template = ERB.new(template_content, trim_mode: "-")

    classes.each do |klass|
      content = template.result(binding)
      output_path = output_path_for(klass)
      out_file = Pathname.new("#{output_dir}/#{output_path}")
      out_file.dirname.mkpath
      File.write(out_file, finalize_markdown(content, current_output_path: output_path))
    end
  end

  # Writes one Markdown file per selected text page.
  #
  # @return [void]
  def emit_pagefiles
    pages.each do |page|
      output_path = page_output_path(page)
      out_file = Pathname.new("#{output_dir}/#{output_path}")
      out_file.dirname.mkpath

      next FileUtils.cp(File.expand_path(page.absolute_name, source_dir), out_file) if page.relative_name.match?(/\.(?:md|markdown)\z/i)

      content = markdownify(render_description(page))
      File.write(out_file, finalize_markdown(content, current_output_path: output_path))
    end
  end

  # Prepares sorted objects and link lookup state for generation.
  #
  # @return [void]
  def setup
    output_dir = options.op_dir
    unless output_dir.instance_of?(String)
      raise TypeError, "RDoc markdown output directory must be a String"
    end

    classes = Selection.classes(store)
    class_output_paths = classes.to_h { |klass| [klass.full_name, output_path_for(klass)] }
    pages = Selection.pages(store)

    @generation_state = GenerationState.new(
      output_dir: output_dir,
      classes: classes,
      pages: pages,
      class_output_paths: class_output_paths,
      markdown_output_object_ids: (classes + pages).map(&:object_id),
      known_output_paths: class_output_paths.values + pages.map { |page| page_output_path(page) },
      root_path_segment: Pathname.new(options.root || ".").basename
    )
  end

  # Returns the prepared output directory.
  #
  # @return [String] Output directory.
  def output_dir
    generation_state.output_dir
  end
end

# RDoc configuration extended with markdown generator options.
class RDoc::Options
  prepend RDoc::Generator::Markdown::OptionsExtension

  # Controls how reverse_markdown handles unknown HTML tags.
  #
  # @return [Symbol]
  attr_reader :markdown_unknown_tags

  # Sets how reverse_markdown handles unknown HTML tags.
  #
  # @param value [Symbol] Unknown-tag handling mode.
  #
  # @return [Symbol]
  attr_writer :markdown_unknown_tags
end
