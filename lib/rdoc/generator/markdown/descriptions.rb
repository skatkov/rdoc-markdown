# frozen_string_literal: true

# Renders RDoc descriptions and metadata for Markdown templates.
module RDoc::Generator::Markdown::Descriptions
  private

  # Renders a class or module reference, linking it when its documentation is emitted.
  #
  # @param target [RDoc::ClassModule, String] Resolved RDoc object or unresolved name.
  # @param label [String] Visible reference text.
  #
  # @return [String] Markdown text or link.
  def metadata_reference(target, label)
    cell = metadata_table_cell(label)
    return cell unless RDoc::ClassModule === target

    output_path = generation_state.class_output_paths[target.full_name]
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

  # Renders an RDoc description with links limited to emitted objects.
  #
  # @param code_object [RDoc::CodeObject, RDoc::Context::Section] Object whose description is rendered.
  # @param heading_level_offset [Integer] Levels to add to comment headings.
  #
  # @return [String] Markdown description.
  def render_description(code_object, heading_level_offset:)
    formatter = RDoc::Generator::Markdown::Formatter.new(
      code_object,
      output_object_ids: generation_state.markdown_output_object_ids,
      heading_level_offset: heading_level_offset
    )
    locale = options.locale
    document = if RDoc::Context::Section === code_object
      documents = code_object.comments.map { |comment| localized_comment_document(comment, locale) }
      RDoc::Markup::Document.new(*documents)
    else
      comment = (RDoc::ClassModule === code_object) ? code_object.comment_location : code_object.comment
      comment = RDoc::I18n::Text.new(comment).translate(locale) if locale
      code_object.parse(comment)
    end
    document.accept(formatter).rstrip
  end

  # Parses one section comment, translating a copy when needed.
  #
  # @param comment [RDoc::Comment] Section comment.
  # @param locale [RDoc::I18n::Locale, nil] Translation locale.
  #
  # @return [RDoc::Markup::Document] Parsed comment document.
  def localized_comment_document(comment, locale)
    return comment.parse unless locale && !comment.text.empty?

    translated = comment.dup
    translated.text = RDoc::I18n::Text.new(translated).translate(locale)
    translated.parse
  end

  # Renders an RDoc object's description as Markdown.
  #
  # @param code_object [RDoc::CodeObject] Object with an RDoc description.
  # @param fallback [String, nil] Text to use when the description is empty.
  # @param heading_level_offset [Integer] Heading levels to add while rendering.
  #
  # @return [String] Rendered description or fallback text.
  def describe(code_object, fallback: nil, heading_level_offset: 0)
    comment = code_object.comment
    heading_level_offset = 0 if RDoc::Comment === comment && comment.format == "markdown"
    description = render_description(code_object, heading_level_offset: heading_level_offset)
    description.empty? ? fallback.to_s : description
  end

  # Renders a method description or an alias fallback.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  # @param current_class [RDoc::Context] Class or module currently being rendered.
  # @param heading_level_offset [Integer] Heading levels to add while rendering.
  #
  # @return [String] Rendered method description.
  def method_description(method, current_class:, heading_level_offset:)
    text = describe(method, heading_level_offset: heading_level_offset)
    return text unless text.empty?

    aliased_method = method.is_alias_for
    return "Not documented." unless aliased_method

    name = aliased_method.name
    link = method_link(aliased_method, current_class: current_class)
    link ? "Alias for: [`#{name}`](#{link})" : "Alias for: `#{name}`"
  end

  # Lists aliases that have generated documentation sections.
  #
  # @param method [RDoc::AnyMethod] Canonical method.
  #
  # @return [String, nil] Linked alias list, or nil when none are emitted.
  def method_aliases(method)
    links = method.aliases.filter_map do |aka|
      # RDoc's module_function copies share alias arrays with their instance methods.
      next unless aka.is_alias_for.equal?(method)

      link = method_link(aka, current_class: method.parent)
      "[`#{aka.name}`](#{link})" if link
    end
    return if links.empty?

    "Also known as: #{links.join(", ")}"
  end

  # Builds a Markdown link target for an aliased method.
  #
  # @param method [RDoc::AnyMethod] Target method.
  # @param current_class [RDoc::Context] Class or module currently being rendered.
  #
  # @return [String, nil] Anchor or relative Markdown link target, or nil when the target method or page is omitted.
  def method_link(method, current_class:)
    return unless method.display?

    target_parent = method.parent
    return unless target_parent
    return unless target_parent.method_list.include?(method)

    target_path = generation_state.class_output_paths[target_parent.full_name]
    return unless target_path

    anchor = method.aref
    return "##{anchor}" if target_parent == current_class

    "#{target_path}##{anchor}"
  end
end
