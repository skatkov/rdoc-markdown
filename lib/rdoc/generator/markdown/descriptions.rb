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
  #
  # @return [String] HTML description.
  def render_description(code_object)
    formatter = description_formatter(code_object)
    formatter.extend(RDoc::Generator::Markdown::CrossrefExtension)
    formatter.with_markdown_cross_references(
      RDoc::CrossReference.new(formatter.context),
      generation_state.markdown_output_object_ids
    ) do
      render_formatted_description(code_object, formatter, options.locale)
    end
  end

  # Returns the formatter appropriate for an object or section.
  #
  # @param code_object [RDoc::CodeObject, RDoc::Context::Section] Described object.
  #
  # @return [RDoc::Markup::Formatter] Formatter configured for the object.
  def description_formatter(code_object)
    return code_object.formatter unless RDoc::Context::Section === code_object

    code_object.parent.formatter.dup.tap { |copy| copy.code_object = code_object }
  end

  # Renders an object through its configured formatter.
  #
  # @param code_object [RDoc::CodeObject, RDoc::Context::Section] Described object.
  # @param formatter [RDoc::Markup::Formatter] Formatter receiving parsed markup.
  # @param locale [RDoc::I18n::Locale, nil] Translation locale.
  #
  # @return [String] Formatted HTML description.
  def render_formatted_description(code_object, formatter, locale)
    return code_object.description unless RDoc::Context::Section === code_object

    documents = code_object.comments.map { |comment| localized_comment_document(comment, locale) }
    RDoc::Markup::Document.new(*documents).accept(formatter)
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
    description = render_description(code_object)
    return fallback.to_s if description.empty?

    RDoc::Generator::Markdown::Conversion.markdownify(description, heading_level_offset: heading_level_offset)
  end

  # Renders a section description as Markdown.
  #
  # @param section [RDoc::Context::Section] RDoc section whose description appears before grouped members.
  # @param heading_level_offset [Integer] Heading levels to add while rendering.
  #
  # @return [String] Rendered section description.
  def section_description(section, heading_level_offset:)
    RDoc::Generator::Markdown::Conversion.markdownify(
      render_description(section),
      heading_level_offset: heading_level_offset
    )
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

    alias_description(aliased_method, method_link(aliased_method, current_class: current_class))
  end

  # Formats an alias fallback with an optional target link.
  #
  # @param aliased_method [RDoc::AnyMethod] Alias target.
  # @param link [String, nil] Generated link target.
  #
  # @return [String] Alias description.
  def alias_description(aliased_method, link)
    name = aliased_method.name
    return "Alias for: `#{name}`" unless link

    "Alias for: [`#{name}`](#{link})"
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
    target_path = generation_state.class_output_paths[target_parent.full_name]
    return unless target_path

    anchor = method.aref
    return "##{anchor}" if target_parent == current_class

    "#{target_path}##{anchor}"
  end
end
