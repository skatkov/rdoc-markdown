# frozen_string_literal: true

gem 'rdoc'

require 'pathname'
require 'erb'
require 'reverse_markdown'
require 'unindent'
require 'csv'

class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  ##
  # Defines a constant for directory where templates could be found

  TEMPLATE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'templates'))

  ##
  # The RDoc::Store that is the source of the generated content

  attr_reader :store, :base_dir, :classes

  ##
  # The path to generate files into, combined with <tt>--op</tt> from the
  # options for a full path.

  ##
  # Classes and modules to be used by this generator, not necessarily
  # displayed.

  ##
  # Directory where generated class HTML files live relative to the output
  # dir.

  def class_dir
    nil
  end

  # this alias is required for rdoc to work
  alias file_dir class_dir

  ##
  # Initializer method for Rdoc::Generator::Markdown

  def initialize(store, options)
    @store = store
    @options = options

    @base_dir = Pathname.pwd.expand_path

    @classes = nil
  end

  ##
  # Generates markdown files and search index file

  def generate
    debug("Setting things up #{@output_dir}")

    setup

    debug("Generate documentation in #{@output_dir}")

    emit_classfiles

    debug("Generate index file in #{@output_dir}")

    emit_csv_index
  end

  private

  attr_reader :options, :output_dir

  ##
  # This method is used to output debugging information in case rdoc is run with --debug parameter

  def debug(str = nil)
    return unless $DEBUG_RDOC

    puts "[rdoc-markdown] #{str}" if str
    yield if block_given?
  end

  ##
  # This class emits a search index for generated documentation as sqlite database
  #

  def emit_csv_index(name = 'index.csv')
    filepath = "#{output_dir}/#{name}"

    CSV.open(filepath, 'wb') do |csv|
      csv << %w[name type path]

      @classes.map do |klass|
        csv << [
          klass.full_name,
          klass.type.capitalize,
          turn_to_path(klass.full_name)
        ]

        klass.method_list.select(&:display?).each do |method|
          csv << [
            "#{klass.full_name}.#{method.name}",
            'Method',
            "#{turn_to_path(klass.full_name)}##{method.aref}"
          ]
        end

        klass
          .constants
          .select(&:display?)
          .sort_by { |x| x.name }
          .each do |const|
            csv << [
              "#{klass.full_name}.#{const.name}",
              'Constant',
              "#{turn_to_path(klass.full_name)}##{const.name}"
            ]
          end

        klass
          .attributes
          .select(&:display?)
          .sort_by { |x| x.name }
          .each do |attr|
            csv << [
              "#{klass.full_name}.#{attr.name}",
              'Attribute',
              "#{turn_to_path(klass.full_name)}##{attr.aref}"
            ]
          end
      end
    end
  end

  def emit_classfiles
    template_content = File.read(File.join(TEMPLATE_DIR, 'classfile.md.erb'))
    template = ERB.new(template_content, trim_mode: '-')

    @classes.each do |klass|
      out_file = Pathname.new("#{output_dir}/#{turn_to_path klass.full_name}")
      out_file.dirname.mkpath

      result = finalize_markdown(template.result(binding))

      File.write(out_file, result)
    end
  end

  ##
  # Takes a class name and converts it into a Pathname

  def turn_to_path(class_name)
    "#{class_name.gsub('::', '/')}.md"
  end

  ##
  # Converts HTML string into a Markdown string with some cleaning and improvements.

  # FIXME: This could return string with newlines in the end, which is not good.
  def markdownify(input)
    # TODO: I should be able to set unknown_tags to "raise" for debugging purposes. Probably through rdoc parameters?
    # Allowed parameters:
    # - pass_through - (default) Include the unknown tag completely into the result
    # - drop - Drop the unknown tag and its content
    # - bypass - Ignore the unknown tag but try to convert its content
    # - raise - Raise an error to let you know

    md = ReverseMarkdown.convert(input.to_s, unknown_tags: :bypass, github_flavored: true)

    # unintent multiline strings
    md.unindent!

    # Remove RDoc navigation links from generated headings.
    md.gsub!(/(#+\s+[^\n]+?)\s*\[¶\]\([^)]+\)(?:\s*\[↑\]\(#top\))?/, '\\1')
    md.gsub!(/\s+\[↑\]\(#top\)$/, '')

    # Replace .html to .md extension in all local markdown links.
    md.gsub!(%r{\]\((?!https?://|mailto:|#)([^)]+?)\.html((?:[?#][^)]+)?)\)}i, '](\\1.md\\2)')

    md = md.gsub('=== ', '### ').gsub('== ', '## ')
    md = normalize_definition_list_code_blocks(md)
    md.lines.map(&:rstrip).join("\n").strip
  end

  # Aliasing a shorter method name for use in templates
  alias h markdownify

  def anchor(id)
    %(<a id="#{id}"></a>)
  end

  def describe(code_object, fallback: nil, heading_level_offset: 0)
    description = code_object.description.to_s
    return fallback.to_s if description.strip.empty? && !fallback.nil?

    shift_headings(markdownify(description), heading_level_offset)
  end

  def section_description(section, heading_level_offset: 0)
    description = section_description_html(section)
    return '' if description.strip.empty?

    shift_headings(markdownify(description), heading_level_offset)
  end

  def method_signature(method)
    signature = method.param_seq.to_s
    return '()' if signature.strip.empty?

    signature = signature.gsub('->', ' -> ')
    signature = signature.gsub(/\s+/, ' ').strip
    signature = " #{signature}" if signature.start_with?('->')
    signature
  end

  def finalize_markdown(content)
    output = content.lines.map(&:rstrip).join("\n")
    output.gsub!(/\n{3,}/, "\n\n")
    "#{output.strip}\n"
  end

  def shift_headings(markdown, heading_level_offset)
    return markdown if heading_level_offset.zero?

    markdown.gsub(/^(#+)(\s+)/) do
      hashes = Regexp.last_match(1)
      spaces = Regexp.last_match(2)
      level = [hashes.length + heading_level_offset, 6].min
      "#{'#' * level}#{spaces}"
    end
  end

  def section_description_html(section)
    if section.instance_variable_defined?(:@store)
      section_store = section.instance_variable_get(:@store)
      parent_store = section.respond_to?(:parent) && section.parent.respond_to?(:store) ? section.parent.store : nil
      section.instance_variable_set(:@store, parent_store) if section_store.nil? && !parent_store.nil?
    end

    section.description.to_s
  rescue NoMethodError
    comments = section.respond_to?(:comments) ? section.comments : nil
    return '' if comments.nil? || comments.empty?

    comments.map { |comment| comment.respond_to?(:text) ? comment.text : comment.to_s }.join("\n")
  end

  def normalize_definition_list_code_blocks(markdown)
    markdown.gsub(/```\n(.*?)\n```/m) do
      body = Regexp.last_match(1)
      converted = convert_definition_list_block(body)
      converted.nil? ? Regexp.last_match(0) : converted
    end
  end

  def convert_definition_list_block(body)
    lines = body.lines.map(&:rstrip)
    return nil if lines.empty?
    return nil unless lines.any? { |line| line.strip.end_with?('::') }
    return nil unless lines.all? { |line| definition_list_line?(line) }

    lines.filter_map do |line|
      stripped = line.strip
      next '' if stripped.empty?
      next "#{stripped.sub(/::\z/, '')}:" if stripped.end_with?('::')

      "- #{stripped.sub(/^\*\s+/, '')}"
    end.join("\n")
  end

  def definition_list_line?(line)
    stripped = line.strip
    stripped.empty? || stripped.end_with?('::') || stripped.match?(/^\*\s+/)
  end

  ##
  # Prepares for document generation, by creating required folders and initializing variables.
  # Could be called multiple times.

  def setup
    return if instance_variable_defined?(:@output_dir)

    @output_dir = Pathname.new(@options.op_dir).expand_path(@base_dir)
    @output_dir.mkpath

    return unless @store

    @classes = @store.all_classes_and_modules.sort
  end
end
