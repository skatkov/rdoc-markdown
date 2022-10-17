# frozen_string_literal: true

gem "rdoc"

require "pathname"
require "erb"
require "reverse_markdown"
require 'extralite'

class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  TEMPLATE_DIR = File.expand_path(
    File.join(File.dirname(__FILE__), "..", "..", "templates")
  )

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
  # Directory where generated class HTML files live relative to the output
  # dir.

  def class_dir
    nil
  end

  # this alias is required for rdoc to work
  alias_method :file_dir, :class_dir

  def initialize(store, options)
    @store = store
    @options = options

    @base_dir = Pathname.pwd.expand_path

    @classes = nil
  end

  def generate
    setup

    debug("Create directory #{@output_dir}")

    output_dir.mkpath

    debug("Generate documentation in #{@output_dir}")

    emit_classfiles

    debug("Generate index db file")
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

  def emit_sqlite
    db = Extralite::Database.new("#{output_dir}index.db")

    db.execute <<-SQL
      create table contentIndex (
        id INTEGER PRIMARY KEY,
        name TEXT,
        type TEXT,
        path TEXT
      );
    SQL

    {
      name: "Enumerable",
      type: "Module",
      path: "Enumerable.md"
    }.each do |rec|
      db.execute "insert into contentIndex (name, type, path) values (:name, :type, :path)", rec
    end
  end

  def emit_classfiles
    @classes.each do |klass|
      klass_methods = []
      instance_methods = []

      klass.method_list.each do |method|
        next if method.visibility.to_s.eql?("private")

        if method.type == "class"
          klass_methods << method
        else
          instance_methods << method
        end
      end

      template = ERB.new File.read(File.join(TEMPLATE_DIR, "classfile.md.erb"))

      out_file = Pathname.new("#{output_dir}/#{turn_to_path klass.full_name}.md")
      out_file.dirname.mkpath

      result = template.result(binding)

      File.write(out_file, result)
    end
  end


  private

  def turn_to_path(class_name)
    class_name.gsub("::", "/")
  end

  def markdownify(input)
    md= ReverseMarkdown.convert input, github_flavored: true

    # Replace .html to .md extension in all markdown links
    md = md.gsub(/\[(.+)\]\((.+).html(.*)\)/) do |_|
      match = Regexp.last_match

      "[#{match[1]}](#{match[2]}.md#{match[3]})"
    end

    # clean up things, to make it look neat.

    md.gsub("[↑](#top)", "").lstrip
  end

  alias_method  :h, :markdownify

  def setup
    return if instance_variable_defined?(:@output_dir)

    @output_dir = Pathname.new(@options.op_dir).expand_path(@base_dir)

    return unless @store

    @classes = @store.all_classes_and_modules.sort
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
