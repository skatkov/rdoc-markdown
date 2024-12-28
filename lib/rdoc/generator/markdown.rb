# frozen_string_literal: true

gem "rdoc"

require "pathname"
require "erb"
require "reverse_markdown"
require "unindent"
require "csv"

class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  ##
  # Defines a constant for directory where templates could be found

  TEMPLATE_DIR = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "templates"))

  ##
  # The RDoc::Store that is the source of the generated content

  attr_reader :store

  ##
  # The path to generate files into, combined with <tt>--op</tt> from the
  # options for a full path.

  attr_reader :base_dir

  ##
  # Classes and modules to be used by this generator, not necessarily
  # displayed.

  attr_reader :classes

  ##
  # Directory where generated class HTML files live relative to the output
  # dir.

  def class_dir
    nil
  end

  # this alias is required for rdoc to work
  alias_method :file_dir, :class_dir

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

  attr_reader :options
  attr_reader :output_dir

  ##
  # This method is used to output debugging information in case rdoc is run with --debug parameter

  def debug(str = nil)
    if $DEBUG_RDOC
      puts "[rdoc-markdown] #{str}" if str
      yield if block_given?
    end
  end

  ##
  # This class emits a search index for generated documentation as sqlite database
  #

  def emit_csv_index(name = "index.csv")
    filepath = "#{output_dir}/#{name}"

    CSV.open(filepath, "wb") do |csv|
       csv << %w[name type path]

      @classes.map do |klass|
        csv << [
          klass.full_name,
          klass.type.capitalize,
          turn_to_path(klass.full_name),
        ]

        klass.method_list.each do |method|
          next if method.visibility.to_s.eql?("private")
          next if method.visibility.to_s.eql?("protected")

          csv << [
            "#{klass.full_name}.#{method.name}",
            "Method",
            "#{turn_to_path(klass.full_name)}##{method.aref}",
          ]
        end

        klass
          .constants
          .sort_by { |x| x.name }
          .each do |const|
            csv << [
              "#{klass.full_name}.#{const.name}",
              "Constant",
              "#{turn_to_path(klass.full_name)}##{const.name}",
            ]
          end

        klass
          .attributes
          .sort_by { |x| x.name }
          .each do |attr|
            csv << [
              "#{klass.full_name}.#{attr.name}",
              "Attribute",
              "#{turn_to_path(klass.full_name)}##{attr.aref}",
            ]
          end
      end
    end
  end

  def emit_classfiles
    @classes.each do |klass|
      template_content = File.read(File.join(TEMPLATE_DIR, "classfile.md.erb"))

      template = ERB.new template_content, trim_mode: ">"

      out_file = Pathname.new("#{output_dir}/#{turn_to_path klass.full_name}")
      out_file.dirname.mkpath

      result = template.result(binding).squeeze("  ")

      File.write(out_file, result)
    end
  end

  ##
  # Takes a class name and converts it into a Pathname

  def turn_to_path(class_name)
    "#{class_name.gsub("::", "/")}.md"
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

    md = ReverseMarkdown.convert input, unknown_tags: :pass_through, github_flavored: true

    # unintent multiline strings
    md.unindent!

    # Replace .html to .md extension in all markdown links
    md.gsub(/\[(.+)\]\((.+).html(.*)\)/) do |_|
      match = Regexp.last_match

      "[#{match[1]}](#{match[2]}.md#{match[3]})"
    end

    md.gsub("=== ", "### ").gsub("== ", "## ")
  end

  # Aliasing a shorter method name for use in templates
  alias_method :h, :markdownify

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
