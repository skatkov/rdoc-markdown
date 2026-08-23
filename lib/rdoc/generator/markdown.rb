# frozen_string_literal: true

require "erb"
require "reverse_markdown"
require "csv"
require "fileutils"

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

  include Descriptions
  include Index
  include Paths
  include Signatures

  # Directory containing ERB templates.
  TEMPLATE_DIR = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "templates"))

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

  # Source store for generated content.
  #
  # @return [RDoc::Store]
  attr_reader :store

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
    @store = store
    @options = rdoc_options
    @source_dir = File.expand_path(rdoc_options.root.to_s)
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

  attr_reader :generation_state, :options, :source_dir

  # Builds an HTML anchor tag.
  #
  # @param id [String] Fragment identifier for the generated anchor.
  #
  # @return [String] HTML anchor tag.
  def anchor(id)
    %(<a id="#{id}"></a>)
  end

  # Applies final whitespace and link normalization before writing Markdown.
  #
  # @param content [String] Markdown content.
  # @param current_output_path [String] Output path for the file being written.
  #
  # @return [String] Final Markdown ending with one newline.
  def finalize_markdown(content, current_output_path:)
    normalized = normalize_internal_links(
      content.lines.map(&:rstrip).join("\n"),
      current_output_path: current_output_path
    ).sub(/\n{3,}/, "\n\n").gsub(/^(#+ .+)\n\n/, "\\1\n")
    "#{normalized}\n"
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

      content = Conversion.markdownify(render_description(page))
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
