# frozen_string_literal: true

gem "rdoc"

require "pathname"
require "erb"

# Markdown generator.
# Registers command line options and generates markdown files
# RDoc documentation and options.
class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  TEMPLATE_DIR = File.expand_path(
    File.join(File.dirname(__FILE__), '..', '..', 'templates'))

  ##
  # The RDoc::Store that is the source of the generated content

  attr_reader :store

  ##
  # The path to generate files into, combined with <tt>--op</tt> from the
  # options for a full path.

  attr_reader :base_dir

  ##
  # Classes and modules to be used by this generator, not necessarily
  # displayed.  See also #modsort

  attr_reader :classes

  ##
  # Files to be displayed by this generator

  attr_reader :files

  ##
  # Methods to be displayed by this generator

  attr_reader :methods

  ##
  # Sorted list of classes and modules to be displayed by this generator

  attr_reader :modsort

  ##
  # Directory where generated class HTML files live relative to the output
  # dir.

  def class_dir
    nil
  end

  def initialize(store, options)
    @store = store
    @options = options

    @base_dir = Pathname.pwd.expand_path

    @classes = nil
    @files = nil
    @methods = nil
    @modsort = nil
  end

  def generate
    setup

    debug("Create directory #{@output_dir}")

    output_dir.mkpath

    debug("Generate documentation in #{@output_dir}")

    emit_classfiles
  end

  private

  attr_reader :options
  attr_reader :output_dir

  def debug(str = nil)
    if $DEBUG_RDOC
      puts "[rdoc-markdown] #{str}" if str
      yield if block_given?
    end
  end

  def emit_classfiles
    @classes.each do |klass|
      klass_methods    = []
      instance_methods = []

      klass.method_list.each do |method|
        next if 'private' == method.visibility.to_s
        if method.type == 'class'
          klass_methods << method
        else
          instance_methods << method
        end
      end

      template = ERB.new File.read(File.join(TEMPLATE_DIR, 'classfile.md.erb'))

      out_file = Pathname.new("#{output_dir}/#{klass.full_name}.md")
      out_file.dirname.mkpath

      File.open(out_file, 'wb') do |f|
        f.write template.result binding
      end
    end
  end

  def setup
    return if instance_variable_defined?(:@output_dir)

    @output_dir = Pathname.new(@options.op_dir).expand_path(@base_dir)

    return unless @store

    @classes = @store.all_classes_and_modules.sort
    @files = @store.all_files.sort
    @methods = @classes.map(&:method_list).flatten.sort
    @modsort = get_sorted_module_list @classes
  end

  ##
  # Return a list of the documented modules sorted by salience first, then
  # by name.

  def get_sorted_module_list classes
    classes.select do |klass|
      klass.display?
    end.sort
  end
end
