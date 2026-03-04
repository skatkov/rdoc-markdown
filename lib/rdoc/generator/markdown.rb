# frozen_string_literal: true

gem 'rdoc'

require 'pathname'
require 'erb'
require 'reverse_markdown'
require 'csv'
require 'cgi'
require 'prism'

class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  ##
  # Defines a constant for directory where templates could be found

  TEMPLATE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'templates'))

  ClassVariableDoc = Struct.new(:name, :description, keyword_init: true)

  ##
  # The RDoc::Store that is the source of the generated content

  attr_reader :store, :base_dir, :classes, :pages

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

    debug("Generate pages in #{@output_dir}")

    emit_pagefiles

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
          display_name(klass),
          klass.type.capitalize,
          output_path_for(klass)
        ]

        klass.method_list.select(&:display?).each do |method|
          csv << [
            "#{display_name(klass)}.#{method.name}",
            'Method',
            "#{output_path_for(klass)}##{method.aref}"
          ]
        end

        klass
          .constants
          .select(&:display?)
          .sort_by { |x| x.name }
          .each do |const|
            csv << [
              "#{display_name(klass)}.#{const.name}",
              'Constant',
              "#{output_path_for(klass)}##{const.name}"
            ]
          end

        class_variables_for(klass).each do |class_variable|
          csv << [
            "#{display_name(klass)}.#{class_variable.name}",
            'Constant',
            "#{output_path_for(klass)}##{class_variable_anchor(class_variable.name)}"
          ]
        end

        klass
          .attributes
          .select(&:display?)
          .sort_by { |x| x.name }
          .each do |attr|
            csv << [
              "#{display_name(klass)}.#{attr.name}",
              'Attribute',
              "#{output_path_for(klass)}##{attr.aref}"
            ]
          end
      end

      @pages.each do |page|
        csv << [
          page.page_name,
          'Page',
          page_output_path(page)
        ]
      end
    end
  end

  def emit_classfiles
    template_content = File.read(File.join(TEMPLATE_DIR, 'classfile.md.erb'))
    template = ERB.new(template_content, trim_mode: '-')

    @classes.each do |klass|
      result = finalize_markdown(template.result(binding), current_output_path: output_path_for(klass))

      out_file = Pathname.new("#{output_dir}/#{output_path_for(klass)}")
      out_file.dirname.mkpath
      File.write(out_file, result)

      legacy_paths_for(klass).each do |legacy_path|
        legacy_file = Pathname.new("#{output_dir}/#{legacy_path}")
        legacy_file.dirname.mkpath
        File.write(legacy_file, result)
      end
    end
  end

  def emit_pagefiles
    @pages.each do |page|
      out_file = Pathname.new("#{output_dir}/#{page_output_path(page)}")
      out_file.dirname.mkpath

      content = markdownify(page.description.to_s)
      File.write(out_file, finalize_markdown(content, current_output_path: page_output_path(page)))
    end
  end

  ##
  # Takes a class name and converts it into a Pathname

  def turn_to_path(class_name)
    "#{class_name.gsub('::', '/')}.md"
  end

  def page_output_path(page)
    source_path = normalize_input_path_for_output(page.relative_name.to_s)
    dirname = File.dirname(source_path)
    basename = "#{File.basename(source_path).tr('.', '_')}.md"

    return basename if dirname == '.'

    "#{dirname}/#{basename}"
  end

  def display_name(code_object)
    class_doc = class_doc_for(code_object)
    class_doc ? class_doc[:display_name] : code_object.full_name
  end

  def output_path_for(code_object)
    class_doc = class_doc_for(code_object)
    class_doc ? class_doc[:output_path] : turn_to_path(code_object.full_name)
  end

  def legacy_paths_for(code_object)
    class_doc = class_doc_for(code_object)
    class_doc ? class_doc[:legacy_paths] : []
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

    html = normalize_rdoc_pre_blocks(input.to_s)

    md = String.new(ReverseMarkdown.convert(html, unknown_tags: :bypass, github_flavored: true))

    # unindent multiline strings
    md = unindent_text(md)

    # Remove RDoc navigation links from generated headings.
    md.gsub!(/(#+\s+[^\n]+?)\s*\[¶\]\([^)]+\)(?:\s*\[↑\]\(#top\))?/) { Regexp.last_match(1) }
    md.gsub!(/\s+\[↑\]\(#top\)$/, '')

    # Flatten headings whose visible text is wrapped in a self-link.
    md.gsub!(/^(#+)\s+\[([^\]]+)\]\((#[^)]+)\)\s*$/) { "#{Regexp.last_match(1)} #{Regexp.last_match(2)}" }

    # Replace .html to .md extension in all local markdown links.
    md.gsub!(%r{\]\((?!https?://|mailto:|#)([^)]+?)\.html((?:[?#][^)]+)?)\)}i) do
      "](#{Regexp.last_match(1)}.md#{Regexp.last_match(2)})"
    end

    # Turn site-root markdown links into relative links.
    md.gsub!(%r{\]\(/([^)]+?\.md(?:[?#][^)]+)?)\)}) { "](#{Regexp.last_match(1)})" }

    # Strip RDoc structural path segments from internal links.
    md.gsub!(%r{\]\(((?:\.\./)*)files/([^)]+?\.md(?:[?#][^)]+)?)\)}) do
      "](#{Regexp.last_match(1)}#{Regexp.last_match(2)})"
    end
    md.gsub!(%r{\]\(((?:\.\./)*)classes/([^)]+?\.md(?:[?#][^)]+)?)\)}) do
      "](#{Regexp.last_match(1)}#{Regexp.last_match(2)})"
    end
    md.gsub!(%r{\]\(((?:\.\./)*)modules/([^)]+?\.md(?:[?#][^)]+)?)\)}) do
      "](#{Regexp.last_match(1)}#{Regexp.last_match(2)})"
    end

    md = md.gsub('=== ', '### ').gsub('== ', '## ')
    md = normalize_definition_list_code_blocks(md)
    md.lines.map(&:rstrip).join("\n").strip
  end

  # Aliasing a shorter method name for use in templates
  alias h markdownify

  def anchor(id)
    %(<a id="#{id}"></a>)
  end

  def class_variables_for(klass)
    @class_variables_by_object_id.fetch(klass.object_id, [])
  end

  def class_variable_anchor(name)
    "classvariable-#{legacy_anchor_component(name, strip_leading_dash: false)}"
  end

  def class_variable_description(class_variable)
    description = class_variable.description.to_s
    return 'Not documented.' if description.strip.empty?

    shift_headings(markdownify(description), 4)
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

  def method_description(method, current_class:)
    text = describe(method, fallback: nil, heading_level_offset: 4)
    return text unless text.empty?

    aliased_method = method.respond_to?(:is_alias_for) ? method.is_alias_for : nil
    return 'Not documented.' unless aliased_method

    "Alias for: [`#{aliased_method.name}`](#{method_link(aliased_method, current_class: current_class)})"
  end

  def finalize_markdown(content, current_output_path: nil)
    output = content.lines.map(&:rstrip).join("\n")
    output = normalize_internal_links(output, current_output_path: current_output_path) if current_output_path
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

  def method_link(method, current_class:)
    target_parent = method.parent
    return "##{method.aref}" if target_parent == current_class

    target_path = output_path_for(target_parent)
    current_path = output_path_for(current_class)
    "#{relative_output_path(current_path, target_path)}##{method.aref}"
  end

  def relative_output_path(from_path, to_path)
    from_dir = Pathname.new(from_path).dirname
    Pathname.new(to_path).relative_path_from(from_dir).to_s
  end

  def normalize_rdoc_pre_blocks(html)
    html.gsub(%r{<pre\b[^>]*>(.*?)</pre>}m) do
      raw = Regexp.last_match(1)
      text = raw
             .gsub(%r{<br\s*/?>}i, "\n")
             .gsub(/<[^>]+>/, '')
      "<pre>#{CGI.unescapeHTML(text)}</pre>"
    end
  end

  def unindent_text(text)
    lines = text.to_s.lines
    indent = lines.reject { |line| line.strip.empty? }.map { |line| line[/^[ \t]*/].size }.min || 0
    return text if indent.zero?

    lines.map { |line| line.sub(/^[ \t]{0,#{indent}}/, '') }.join
  end

  def legacy_anchor_component(text, strip_leading_dash: true)
    escaped = CGI.escape(text.to_s.gsub('-', '-2D')).tr('%', '-')
    strip_leading_dash ? escaped.sub(/^-/, '') : escaped
  end

  def normalize_internal_links(markdown, current_output_path:)
    return markdown if @known_output_paths.nil? || @known_output_paths.empty?

    current_dir = Pathname.new(current_output_path).dirname

    markdown.gsub(%r{\]\((?!https?://|mailto:|#)([^)]+)\)}) do
      target = Regexp.last_match(1)
      path = target.sub(/[?#].*\z/, '')
      suffix = target[path.length..] || ''

      resolved = resolve_output_path(path, current_dir)
      rewritten = resolved ? Pathname.new(resolved).relative_path_from(current_dir).to_s : path
      "](#{rewritten}#{suffix})"
    end
  end

  def resolve_output_path(path, current_dir)
    normalized_path = path.to_s.sub(%r{\A/}, '')
    candidates = [normalized_path]

    stripped = normalized_path.sub(%r{\A(?:files|classes|modules)/}, '')
    candidates << stripped unless stripped == normalized_path

    if @root_path_segment && stripped.start_with?("#{@root_path_segment}/")
      candidates << stripped.delete_prefix("#{@root_path_segment}/")
    end

    candidates = candidates.flat_map { |candidate| candidate_with_parent_reductions(candidate) }.uniq

    candidates.each do |candidate|
      return candidate if @known_output_paths.include?(candidate)
    end

    candidates.each do |candidate|
      expanded = current_dir.join(candidate).cleanpath.to_s
      return expanded if @known_output_paths.include?(expanded)
    end

    nil
  end

  def candidate_with_parent_reductions(candidate)
    reductions = [candidate.sub(%r{\A\./}, '')]
    reduced = reductions.first

    while reduced.start_with?('../')
      reduced = reduced.delete_prefix('../')
      reductions << reduced
    end

    reductions.uniq.reject(&:empty?)
  end

  def normalize_input_path_for_output(path)
    normalized = path.to_s.tr('\\', '/').sub(%r{\A\./}, '')
    normalized = normalized.sub(%r{\A/}, '')

    root = File.expand_path(@options.root || '.', @base_dir).tr('\\', '/')
    normalized = normalized.sub(%r{\A#{Regexp.escape(root)}/}, '')

    root_basename = File.basename(root)
    normalized.sub(%r{\A#{Regexp.escape(root_basename)}/}, '')
  end

  def class_doc_for(code_object)
    @class_docs_by_object_id[code_object.object_id]
  end

  def extract_class_variables
    class_variables = Hash.new { |hash, key| hash[key] = [] }

    @store.all_files.each do |source_file|
      source_path = source_path_for(source_file)
      next unless source_path && File.file?(source_path)
      next unless File.extname(source_path) == '.rb'

      source = File.read(source_path)
      parse_result = Prism.parse(source)
      next unless parse_result.success?

      extract_class_variables_from_node(
        parse_result.value,
        namespace: nil,
        in_method: false,
        source_lines: source.lines,
        class_variables: class_variables
      )
    rescue Errno::ENOENT, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      next
    end

    class_variables
  end

  def extract_class_variables_from_node(node, namespace:, in_method:, source_lines:, class_variables:)
    return unless node.is_a?(Prism::Node)

    case node
    when Prism::ClassNode
      class_name = qualified_namespace(prism_constant_path(node.constant_path), namespace)
      extract_class_variables_from_node(
        node.body,
        namespace: class_name,
        in_method: false,
        source_lines: source_lines,
        class_variables: class_variables
      )
      return
    when Prism::ModuleNode
      module_name = qualified_namespace(prism_constant_path(node.constant_path), namespace)
      extract_class_variables_from_node(
        node.body,
        namespace: module_name,
        in_method: false,
        source_lines: source_lines,
        class_variables: class_variables
      )
      return
    when Prism::SingletonClassNode
      extract_class_variables_from_node(
        node.body,
        namespace: namespace,
        in_method: in_method,
        source_lines: source_lines,
        class_variables: class_variables
      )
      return
    when Prism::DefNode
      in_method = true
    end

    if namespace && !in_method
      name, line_number = class_variable_assignment_details(node)

      if name
        description = comment_above_line(source_lines, line_number)
        unless description.match?(/:nodoc:/)
          class_variables[namespace] << ClassVariableDoc.new(name: name, description: description)
        end
      end
    end

    node.child_nodes.each do |child|
      extract_class_variables_from_node(
        child,
        namespace: namespace,
        in_method: in_method,
        source_lines: source_lines,
        class_variables: class_variables
      )
    end
  end

  def source_path_for(source_file)
    path = if source_file.respond_to?(:absolute_name)
             source_file.absolute_name.to_s
           else
             source_file.full_name.to_s
           end

    return nil if path.empty?

    pathname = Pathname.new(path)
    pathname = pathname.expand_path(@base_dir) unless pathname.absolute?
    pathname.to_s
  end

  def qualified_namespace(path, namespace)
    return namespace if path.nil? || path.empty?

    normalized = path.delete_prefix('::')

    return normalized if path.start_with?('::') || normalized.include?('::')
    return normalized if namespace.nil? || namespace.empty?

    "#{namespace}::#{normalized}"
  end

  def prism_constant_path(constant_path)
    return nil unless constant_path

    constant_path.full_name.to_s
  end

  def class_variable_assignment_details(node)
    return [nil, nil] unless node.is_a?(Prism::Node)

    case node.type
    when :class_variable_write_node,
         :class_variable_and_write_node,
         :class_variable_or_write_node,
         :class_variable_operator_write_node
      [node.name.to_s, node.name_loc.start_line]
    when :class_variable_target_node
      [node.slice.to_s, node.start_line]
    else
      [nil, nil]
    end
  end

  def comment_above_line(source_lines, line_number)
    return '' unless line_number && line_number > 1

    comments = []
    cursor = line_number - 2

    while cursor >= 0
      line = source_lines[cursor]
      break unless line

      match = line.match(/^\s*#(.*)$/)
      break unless match

      comments << normalize_comment_line(match[1])
      cursor -= 1
    end

    comments.reverse.join("\n").rstrip
  end

  def normalize_comment_line(comment_line)
    text = comment_line.to_s
    text.sub(/^ /, '')
  end

  def build_class_docs(classes)
    docs_by_name = {}

    classes.each do |klass|
      display_name = normalized_full_name(klass.full_name)
      output_path = turn_to_path(display_name)
      legacy_path = turn_to_path(klass.full_name)
      score = class_content_score(klass)

      candidate = {
        klass: klass,
        display_name: display_name,
        output_path: output_path,
        legacy_paths: legacy_path == output_path ? [] : [legacy_path],
        score: score
      }

      existing = docs_by_name[display_name]

      if existing.nil?
        docs_by_name[display_name] = candidate
      elsif candidate[:score] > existing[:score]
        if existing[:score].positive?
          candidate[:legacy_paths] |= existing[:legacy_paths] + [turn_to_path(existing[:klass].full_name)]
        end
        docs_by_name[display_name] = candidate
      elsif candidate[:score].positive?
        existing[:legacy_paths] |= candidate[:legacy_paths] + [legacy_path]
      end
    end

    docs_by_name.values
                .select do |doc|
                  doc[:score].positive? ||
                    (doc[:klass].full_name == doc[:display_name] && !synthetic_full_name?(doc[:klass].full_name))
    end
                .sort_by { |doc| doc[:display_name] }
                .map { |doc| doc.tap { |d| d[:legacy_paths].uniq! } }
  end

  def normalized_full_name(full_name)
    normalized = full_name.dup

    loop do
      break unless normalized

      if normalized =~ /\A(.+?)::\1::(.+)\z/
        normalized = "#{::Regexp.last_match(1)}::#{::Regexp.last_match(2)}"
        next
      end

      if normalized =~ /\A([^:]+)(?:::[^:]+)+::\1::(.+)\z/
        normalized = "#{::Regexp.last_match(1)}::#{::Regexp.last_match(2)}"
        next
      end

      if normalized =~ /\A(.+?)::\1\z/
        normalized = Regexp.last_match(1)
        next
      end

      break
    end

    normalized
  end

  def class_content_score(klass)
    score = klass.method_list.size + klass.constants.size + klass.attributes.size
    score += 1 unless klass.description.to_s.strip.empty?
    score
  end

  def synthetic_full_name?(full_name)
    parts = full_name.split('::')
    return false if parts.size < 3

    root = parts.first
    parts.count(root) > 1
  end

  ##
  # Prepares for document generation, by creating required folders and initializing variables.
  # Could be called multiple times.

  def setup
    return if instance_variable_defined?(:@output_dir)

    @output_dir = Pathname.new(@options.op_dir).expand_path(@base_dir)
    @output_dir.mkpath

    return unless @store

    @class_docs = build_class_docs(@store.all_classes_and_modules.sort)
    @class_docs_by_object_id = @class_docs.to_h { |doc| [doc[:klass].object_id, doc] }
    @classes = @class_docs.map { |doc| doc[:klass] }
    @pages = @store.all_files.select(&:text?).select(&:display?).sort_by(&:base_name)

    extracted_class_variables = extract_class_variables
    @class_variables_by_object_id = Hash.new { |hash, key| hash[key] = [] }

    classes_by_full_name = {}
    classes_by_normalized_name = {}

    @classes.each do |klass|
      classes_by_full_name[klass.full_name] = klass
      classes_by_normalized_name[normalized_full_name(klass.full_name)] = klass
    end

    extracted_class_variables.each do |namespace, class_variables|
      klass = classes_by_full_name[namespace] || classes_by_normalized_name[namespace]
      next unless klass

      merged_by_name = {}

      class_variables.each do |class_variable|
        existing = merged_by_name[class_variable.name]

        if existing.nil? ||
           (existing.description.to_s.strip.empty? && !class_variable.description.to_s.strip.empty?)
          merged_by_name[class_variable.name] = class_variable
        end
      end

      @class_variables_by_object_id[klass.object_id] = merged_by_name.values.sort_by(&:name)
    end

    @known_output_paths = Set.new
    @class_docs.each do |doc|
      @known_output_paths << doc[:output_path]
      doc[:legacy_paths].each { |path| @known_output_paths << path }
    end
    @pages.each { |page| @known_output_paths << page_output_path(page) }

    @root_path_segment = Pathname.new(@options.root || '.').basename.to_s
  end
end
