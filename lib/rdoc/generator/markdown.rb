# frozen_string_literal: true

require "erb"
require "reverse_markdown"
require "csv"
require "fileutils"
require "optparse"

# Generates Markdown output and a CSV search index from an RDoc store.
class RDoc::Generator::Markdown
  RDoc::RDoc.add_generator self

  require_relative "markdown/crossref"

  # Directory containing ERB templates.
  TEMPLATE_DIR = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "templates"))

  # Supported reverse_markdown unknown-tag modes.
  MARKDOWN_UNKNOWN_TAGS = %i[pass_through drop bypass raise].freeze

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
  attr_reader :store

  # Classes and modules selected for output.
  #
  # @return [Array<RDoc::Context>, nil]
  attr_reader :classes

  # Text files selected for output.
  #
  # @return [Array<RDoc::TopLevel>, nil]
  attr_reader :pages

  # Creates a generator for an RDoc store and options.
  #
  # @param store [RDoc::Store] Source documentation store.
  # @param rdoc_options [RDoc::Options] Generator options.
  def initialize(store, rdoc_options)
    @store = store
    @options = rdoc_options
    @source_dir = File.expand_path(rdoc_options.root.to_s)
    @markdown_unknown_tags = self.class.validate_markdown_unknown_tags(rdoc_options.markdown_unknown_tags)
  end

  # Writes class files, page files, and the search index.
  #
  # @return [void]
  def generate
    debug("Setting things up ")

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

  # Writes a CSV search index for generated documentation.
  #
  # @return [void]
  def emit_csv_index
    filepath = "#{output_dir}/index.csv"

    CSV.open(filepath, "wb") do |csv|
      csv << %w[name type path]

      @classes.each do |klass|
        csv << [
          klass.full_name,
          klass.type.capitalize,
          output_path_for(klass)
        ]

        klass.method_list.select(&:display?).each do |method|
          csv << [
            "#{klass.full_name}.#{method.name}",
            "Method",
            "#{output_path_for(klass)}##{method.aref}"
          ]
        end

        klass
          .constants
          .select(&:display?)
          .sort
          .each do |const|
            csv << [
              "#{klass.full_name}.#{const.name}",
              "Constant",
              "#{output_path_for(klass)}##{const.name}"
            ]
          end

        klass
          .attributes
          .select(&:display?)
          .sort
          .each do |attr|
            csv << [
              "#{klass.full_name}.#{attr.name}",
              "Attribute",
              "#{output_path_for(klass)}##{attr.aref}"
            ]
          end
      end

      @pages.each do |page|
        csv << [
          page.page_name,
          "File",
          page_output_path(page)
        ]
      end
    end
  end

  # Writes one Markdown file per selected class or module.
  #
  # @return [void]
  def emit_classfiles
    template_content = File.read(File.join(TEMPLATE_DIR, "classfile.md.erb"))
    template = ERB.new(template_content, trim_mode: "-")

    @classes.each do |klass|
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
    @pages.each do |page|
      out_file = Pathname.new("#{output_dir}/#{page_output_path(page)}")
      out_file.dirname.mkpath

      next FileUtils.cp(File.expand_path(page.absolute_name, @source_dir), out_file) if page.relative_name.match?(/\.(?:md|markdown)\z/i)

      content = markdownify(render_description(page))
      File.write(out_file, finalize_markdown(
        content,
        current_output_path: page_output_path(page)
      ))
    end
  end

  # Converts a qualified object name into a Markdown path.
  #
  # @param class_name [String] Qualified class or module name.
  #
  # @return [String] Relative Markdown path.
  def turn_to_path(class_name)
    "#{class_name.gsub("::", "/")}.md"
  end

  # Builds the Markdown output path for an RDoc page.
  #
  # @param page [RDoc::TopLevel] Page object to render.
  #
  # @return [String] Relative Markdown path.
  def page_output_path(page)
    source_path = normalize_input_path_for_output(page.relative_name)
    return source_path if page.relative_name.match?(/\.(?:md|markdown)\z/i)

    dirname = File.dirname(source_path)
    basename = "#{File.basename(source_path).tr(".", "_")}.md"

    return basename if dirname == "."

    "#{dirname}/#{basename}"
  end

  # Returns the canonical Markdown path for a class or module.
  #
  # @param code_object [RDoc::Context] Class or module object.
  #
  # @return [String] Relative Markdown path.
  def output_path_for(code_object)
    turn_to_path(code_object.full_name)
  end

  # Renders a class or module reference, linking it when its documentation is emitted.
  #
  # @param target [RDoc::ClassModule, String] Resolved RDoc object or unresolved name.
  # @param label [String] Visible reference text.
  #
  # @return [String] Markdown text or link.
  def metadata_reference(target, label)
    output_path = @class_output_paths[target.full_name] if target.respond_to?(:full_name)
    cell = metadata_table_cell(label)
    return cell unless output_path

    "[#{cell}](#{output_path})"
  end

  # Escapes text for a Markdown table cell.
  #
  # @param value [String] Metadata text.
  #
  # @return [String] GFM table-safe Markdown text.
  def metadata_table_cell(value)
    value.gsub(/[[:blank:]]*\R[[:blank:]]*/, " ")
      .gsub(/[\\|]/) { |character| "\\#{character}" }
  end

  # Converts RDoc HTML into GitHub-flavored Markdown.
  #
  # @param input [String] RDoc HTML fragment.
  #
  # @return [String] Markdown with normalized links and no trailing whitespace.
  def markdownify(input)
    # ReverseMarkdown supports these unknown-tag modes:
    # - pass_through - (default) Include the unknown tag completely into the result
    # - drop - Drop the unknown tag and its content
    # - bypass - Ignore the unknown tag but try to convert its content
    # - raise - Raise an error to let you know

    fragment = Nokogiri::HTML.fragment(input)
    fragment.css("span.legacy-anchor[id]").select do |span|
      span.next_element&.name == "h1" && span["id"].match?(/\A(?:class|module)-/)
    end.each(&:remove)
    fragment.css("span.legacy-anchor[id]").each do |span|
      heading = span.next_element
      heading.add_child(span) if heading&.name&.match?(/\Ah[1-6]\z/)
    end

    fragment.css("pre").each do |pre|
      language = pre["class"].to_s[/\A(?!highlight\z)[A-Za-z][A-Za-z0-9_+-]*\z/]
      pre["class"] = "brush: #{language};" if language
      pre.inner_html = pre.text
    end

    fragment.css("h1, h2, h3, h4, h5, h6").each do |heading|
      link = heading.xpath("./a[starts-with(@href, '#') and string-length(@href) > 1]").find do |anchor|
        anchor.text.match?(/\S/) &&
          anchor.xpath("preceding-sibling::node()").none? { |sibling| sibling.text.match?(/\S/) }
      end
      next unless link

      id = link["href"].delete_prefix("#")
      link.replace(link.children)
      next if id == RDoc::Text.to_anchor(heading.text)

      heading.add_child(fragment.document.create_element("span", "class" => "legacy-anchor", "id" => id))
    end

    anchor_aliases = fragment.css("span.legacy-anchor[id]").map.with_index do |span, index|
      token = "RDocMarkdownAnchor#{index}End"
      id = span["id"]
      span.replace(token)
      [token, id]
    end

    fragment.css("a").each do |link|
      receiver = link.text
      href = link["href"].to_s

      if receiver.match?(/\A(?:[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*|[a-z_][A-Za-z0-9_]*)\z/) &&
          href.match?(/\A(?::.+|".+")\z/)
        link.replace(fragment.document.create_element("code") { |code| code.content = "#{receiver}[#{href}]" })
      elsif href.start_with?("www.")
        link["href"] = "https://#{href}"
      elsif !href.match?(/\A(?:https?:\/\/|mailto:|#)/i)
        href = href.sub(/\.html(?=[?#]|\z)/i, ".md")
        href = href.sub(%r{\A/(?=.+\.md(?:[?#]|\z))}, "")
        href = href.sub(%r{\A((?:\.\./)*)(?:files|classes|modules)/(?=.+\.md(?:[?#]|\z))}, '\1')
        link["href"] = href
      end
    end

    md = ReverseMarkdown.convert(
      fragment,
      github_flavored: true,
      unknown_tags: @markdown_unknown_tags
    ).dup
    anchor_aliases.each do |token, id|
      md.gsub!(token, %(<a id="#{id}"></a>))
    end

    normalize_definition_list_code_blocks(md).rstrip
  end

  # Short alias used by ERB templates.
  alias_method :h, :markdownify

  # Builds an HTML anchor tag.
  #
  # @param id [String] Fragment identifier for the generated anchor.
  #
  # @return [String] HTML anchor tag.
  def anchor(id)
    %(<a id="#{id}"></a>)
  end

  # Renders an RDoc description with links limited to emitted objects.
  #
  # @param code_object [RDoc::CodeObject, RDoc::Context::Section] Object whose description is rendered.
  #
  # @return [String] HTML description.
  def render_description(code_object)
    section = RDoc::Context::Section === code_object
    formatter = if section
      code_object.parent.formatter.dup.tap { |copy| copy.code_object = code_object }
    else
      code_object.formatter
    end
    formatter.extend(CrossrefExtension)
    begin
      formatter.markdown_cross_reference = RDoc::CrossReference.new(formatter.context)
      formatter.markdown_output_object_ids = @markdown_output_object_ids
      if section
        locale = options.locale
        documents = code_object.comments.map do |comment|
          next comment.parse unless locale && !comment.text.empty?

          comment = comment.dup
          comment.text = RDoc::I18n::Text.new(comment).translate(locale)
          comment.parse
        end
        RDoc::Markup::Document.new(*documents).accept(formatter)
      else
        code_object.description
      end
    ensure
      formatter.markdown_cross_reference = nil
    end
  end

  # Renders an RDoc object's description as Markdown.
  #
  # @param code_object [RDoc::CodeObject] Object with an RDoc description.
  # @param fallback [String, nil] Text to use when the description is empty.
  # @param heading_level_offset [Integer] Heading levels to add while rendering.
  #
  # @return [String] Rendered description or fallback text.
  def describe(code_object, fallback: nil, heading_level_offset: 0)
    description = render_description(code_object)
    return fallback.to_s if description.empty?

    shift_headings(markdownify(description), heading_level_offset)
  end

  # Renders a section description as Markdown.
  #
  # @param section [RDoc::Context::Section] RDoc section whose description appears before grouped members.
  # @param heading_level_offset [Integer] Heading levels to add while rendering.
  #
  # @return [String] Rendered section description.
  def section_description(section, heading_level_offset:)
    shift_headings(markdownify(render_description(section)), heading_level_offset)
  end

  # Builds the visible method signature used in headings.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  #
  # @return [String] Normalized method signature.
  def method_signature(method)
    signatures = method.type_signature_lines || @store.rbs_signature_for(method) || [method.param_seq]

    signatures = signatures.filter_map do |signature|
      next unless signature&.match?(/\S/)

      signature = signature.gsub("->", " -> ")
      signature = signature.gsub(/\s+/, " ").strip
      signature = " #{signature}" if signature.start_with?("->")
      merge_method_signature_arguments(signature, method.params)
    end

    return "()" if signatures.empty?

    signatures.join(" | ")
  end

  # Merges RDoc parameter names into a type-only signature.
  #
  # @param signature [String] Method signature from RDoc call sequence.
  # @param raw_params [String, nil] Method parameter list from RDoc.
  #
  # @return [String] Signature with names added when safe.
  def merge_method_signature_arguments(signature, raw_params)
    params = normalized_method_params(raw_params)

    signature_args, signature_suffix = split_signature_arguments_and_suffix(signature)
    return signature if signature_args.nil?

    param_parts = split_signature_list(params)
    signature_parts = split_signature_list(signature_args)
    return signature unless param_parts.length.eql?(signature_parts.length)

    param_names = param_parts.map { |part| extract_parameter_name(part) }
    return signature if param_names.any?(&:nil?)
    return signature if signature_parts.zip(param_names).all? { |part, name| signature_part_mentions_name?(part, name) }

    merged_args = param_parts.zip(signature_parts).map do |param, type|
      separator = param.end_with?(":") ? " " : ": "
      "#{param}#{separator}#{type}"
    end

    "(#{merged_args.join(", ")})#{signature_suffix}"
  end

  # Normalizes RDoc's raw parameter string.
  #
  # @param raw_params [String, nil] Parameter list from RDoc.
  #
  # @return [String] Parameter list without outer parentheses.
  def normalized_method_params(raw_params)
    params = raw_params.to_s.strip
    params = params[1...-1] if params.start_with?("(") && params.end_with?(")")

    params
  end

  # Splits a parenthesized signature into arguments and suffix.
  #
  # @param signature [String] Method signature.
  #
  # @return [Array<String>, nil] Argument text and suffix, or nil when not parenthesized.
  def split_signature_arguments_and_suffix(signature)
    return unless signature.start_with?("(")

    depth = 0

    signature.each_char.with_index do |char, index|
      depth += 1 if char == "("

      next unless char == ")"

      depth -= 1
      return [signature[1...index], signature[(index + 1)..]] if depth.zero?
    end
  end

  # Splits a comma-separated signature list while preserving nested groups.
  #
  # @param list [String] Signature argument list.
  #
  # @return [Array<String>] Signature parts.
  def split_signature_list(list)
    parts = []
    current = +""
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0

    list.each_char do |char|
      case char
      when "("
        paren_depth += 1
      when ")"
        paren_depth -= 1
      when "["
        bracket_depth += 1
      when "]"
        bracket_depth -= 1
      when "{"
        brace_depth += 1
      when "}"
        brace_depth -= 1
      when ","
        if paren_depth.zero? && bracket_depth.zero? && brace_depth.zero?
          parts << current.strip
          current = +""
          next
        end
      end

      current << char
    end

    parts << current.strip unless current.empty?
    parts
  end

  # Extracts a bare Ruby parameter name from a parameter fragment.
  #
  # @param parameter [String] Parameter fragment.
  #
  # @return [String, nil] Parameter name, or nil when invalid.
  def extract_parameter_name(parameter)
    match = parameter.match(/\A(?:\*\*|\*|&)?([a-z_]\w*):?\z/)
    match && match[1]
  end

  # Checks whether a signature fragment already includes a parameter name.
  #
  # @param text [String] Signature fragment.
  # @param name [String] Parameter name.
  #
  # @return [Boolean] True when the name appears as a standalone word.
  def signature_part_mentions_name?(text, name)
    text.match?(/(?<!\w)#{name}(?!\w)/)
  end

  # Renders a method description or an alias fallback.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  # @param current_class [RDoc::Context] Class or module currently being rendered.
  #
  # @return [String] Rendered method description.
  def method_description(method, current_class:)
    text = describe(method, heading_level_offset: 4)
    return text unless text.empty?

    aliased_method = method.is_alias_for
    return "Not documented." unless aliased_method

    link = method_link(aliased_method, current_class: current_class)
    return "Alias for: `#{aliased_method.name}`" unless link

    "Alias for: [`#{aliased_method.name}`](#{link})"
  end

  # Applies final whitespace and link normalization before writing Markdown.
  #
  # @param content [String] Markdown content.
  # @param current_output_path [String] Output path for the file being written.
  #
  # @return [String] Final Markdown ending with one newline.
  def finalize_markdown(content, current_output_path:)
    output = content.lines.map(&:rstrip).join("\n")
    output = normalize_internal_links(output, current_output_path: current_output_path)
    output = output.sub(/\n{3,}/, "\n\n")
    output = output.gsub(/^(#+ .+)\n\n/, "\\1\n")
    "#{output}\n"
  end

  # Increases Markdown heading levels without exceeding level six.
  #
  # @param markdown [String] Markdown content.
  # @param heading_level_offset [Integer] Heading levels to add.
  #
  # @return [String] Markdown with shifted headings.
  def shift_headings(markdown, heading_level_offset)
    markdown.gsub(/^(#+)(\s)/) do
      hashes = Regexp.last_match(1)
      spaces = Regexp.last_match(2)
      level = [hashes.length + heading_level_offset, 6].min
      "#{"#" * level}#{spaces}"
    end
  end

  # Converts RDoc definition-list code blocks into Markdown lists.
  #
  # @param markdown [String] Markdown content.
  #
  # @return [String] Markdown with convertible blocks normalized.
  def normalize_definition_list_code_blocks(markdown)
    markdown.gsub(/```[^\n]*\n(.+?)\n```/m) do
      body = Regexp.last_match(1)
      converted = convert_definition_list_block(body)
      converted.nil? ? Regexp.last_match : converted
    end
  end

  # Converts a single definition-list code block.
  #
  # @param body [String] Code block body.
  #
  # @return [String, nil] Converted Markdown, or nil when the block is not a definition list.
  def convert_definition_list_block(body)
    lines = body.lines
    return nil unless lines.all? { |line| definition_list_line?(line) }

    lines.map do |line|
      stripped = line.strip
      next if stripped.empty?
      next "#{stripped.sub(/::\z/, "")}:" if stripped.end_with?("::")

      "- #{stripped.sub(/\A\*\s/, "")}"
    end.join("\n")
  end

  # Checks whether a line can appear in a converted definition list.
  #
  # @param line [String] Markdown line.
  #
  # @return [Boolean] True when the line matches RDoc definition-list output.
  def definition_list_line?(line)
    stripped = line.strip
    stripped.empty? || stripped.end_with?("::") || stripped.match?(/\A\*\s/)
  end

  # Builds a Markdown link target for an aliased method.
  #
  # @param method [RDoc::AnyMethod] Target method.
  # @param current_class [RDoc::Context] Class or module currently being rendered.
  #
  # @return [String, nil] Anchor or relative Markdown link target, or nil when the target page is omitted.
  def method_link(method, current_class:)
    return unless method.display?

    target_parent = method.parent
    target_path = @class_output_paths[target_parent.full_name]
    return unless target_path
    return "##{method.aref}" if target_parent == current_class

    "#{target_path}##{method.aref}"
  end

  # Rewrites local Markdown links relative to the current output file.
  #
  # @param markdown [String] Markdown content.
  # @param current_output_path [String] Output path for the file being written.
  #
  # @return [String] Markdown with normalized internal links.
  def normalize_internal_links(markdown, current_output_path:)
    current_dir = Pathname.new(current_output_path).dirname

    markdown.gsub(%r{\]\(([^)]+)\)}) do
      target = Regexp.last_match(1)
      path = target.sub(/[?#].*\z/, "")
      suffix = target[path.length..]

      resolved = resolve_output_path(path, current_dir)
      rewritten = resolved ? Pathname.new(resolved).relative_path_from(current_dir) : path
      "](#{rewritten}#{suffix})"
    end
  end

  # Resolves an internal link path against known generated outputs.
  #
  # @param path [String] Link path from Markdown content.
  # @param current_dir [Pathname] Directory of the current output file.
  #
  # @return [String, nil] Resolved output path, or nil when unresolved.
  def resolve_output_path(path, current_dir)
    candidates = [path, path.delete_prefix("#{@root_path_segment}/")]
    candidates += candidates.map { |candidate| candidate.sub(/_(md|markdown)\.md\z/i, '.\1') }

    candidates.each do |candidate|
      return candidate if @known_output_paths.include?(candidate)
    end

    candidates.each do |candidate|
      expanded = current_dir.join(candidate).cleanpath.to_s
      return expanded if @known_output_paths.include?(expanded)
    end

    nil
  end

  # Normalizes an input filename into an output-relative source path.
  #
  # @param path [String] RDoc input path.
  #
  # @return [String] Normalized path without root prefixes.
  def normalize_input_path_for_output(path)
    normalized = path.tr("\\", "/").sub(%r{\A\./}, "")

    root = @source_dir
    normalized = normalized.sub(%r{\A#{Regexp.escape(root)}/}, "")
    normalized = normalized.sub(%r{\A/}, "")

    root_basename = File.basename(root)
    normalized.sub(%r{\A#{Regexp.escape(root_basename)}/}, "")
  end

  # Prepares sorted objects and link lookup state for generation.
  #
  # @return [void]
  def setup
    @output_dir = @options.op_dir
    unless @output_dir.instance_of?(String)
      raise TypeError, "RDoc markdown output directory must be a String"
    end

    @classes = @store.unique_classes_and_modules.select(&:display?).select do |klass|
      klass.in_files.any? ||
        klass.documented? ||
        klass.includes.any? ||
        klass.method_list.any?(&:display?) ||
        klass.constants.any?(&:display?) ||
        klass.attributes.any?(&:display?) ||
        klass.sections.any? { |section| section.title.to_s.match?(/\S/) || !section.to_document.empty? }
    end.sort
    @class_output_paths = @classes.to_h { |klass| [klass.full_name, output_path_for(klass)] }
    @pages = @store.all_files.select(&:text?).select(&:display?)
      .select { |page| page.relative_name.match?(/\.(?:md|markdown|rdoc)\z/i) }
      .sort_by(&:base_name)
    @markdown_output_object_ids = (@classes + @pages).map(&:object_id)
    @known_output_paths = @class_output_paths.values
    @pages.each { |page| @known_output_paths << page_output_path(page) }

    @root_path_segment = Pathname.new(@options.root || ".").basename
  end
end

# RDoc configuration extended with markdown generator options.
class RDoc::Options
  prepend RDoc::Generator::Markdown::OptionsExtension

  # Controls how reverse_markdown handles unknown HTML tags.
  #
  # @return [Symbol]
  attr_accessor :markdown_unknown_tags
end
