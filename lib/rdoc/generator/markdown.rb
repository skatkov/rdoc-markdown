gem 'rdoc'

require 'pathname'

class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

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
  end

  def generate
    setup

    debug("Create directory #{@output_dir}")

    output_dir.mkpath

    debug("Generate documentation in #{@output_dir}")

    generate_class_files
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

  ##
  # Generate a documentation file for each class and module

  def generate_class_files
    setup

    debug("Generate class documentation in #{output_dir}")

    current = nil

    @classes.each do |klass|
      current = klass

      generate_class klass
    end
  end

  ##
  # Generates a class file for +klass+

  def generate_class klass
    debug "  working on %s (%s)" % [klass.full_name, klass.path]

    out_file = output_dir + klass.path

    debug "Outputting to %s" % [out_file.expand_path]

    out_file.dirname.mkpath
    out_file.open("w", 0644) do |io|
      io.set_encoding options.encoding

      'test'
    end
  end

  def setup
    return if instance_variable_defined?(:@output_dir)

    @output_dir = Pathname.new( @options.op_dir).expand_path( @base_dir )

    return unless @store

    @classes = @store.all_classes_and_modules.sort
    @files = @store.all_files.sort
    @methods = @classes.map {|m| m.method_list }.flatten.sort
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
