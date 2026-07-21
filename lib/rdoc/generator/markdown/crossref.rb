# frozen_string_literal: true

# Adapts RDoc 7 and 8 cross-reference resolver and link-text APIs.
class RDoc::Generator::Markdown::CrossrefAdapter
  # Creates an adapter for cross-references in the given context.
  #
  # @param context [RDoc::Context] Context used to resolve references.
  def initialize(context)
    @resolver = RDoc::CrossReference.new(context)
    @resolve_with_text = @resolver.public_method(:resolve).arity == 2
  end

  # Resolves a cross-reference across supported RDoc versions.
  #
  # @param name [String, nil] Cross-reference target.
  # @param text [String] Visible link text.
  #
  # @return [RDoc::CodeObject, String, nil] Resolved object or fallback.
  def resolve(name, text)
    return unless name

    @resolve_with_text ? @resolver.resolve(name, text) : @resolver.resolve(name)
  end

  # Normalizes link text to escaped HTML across supported RDoc versions.
  #
  # @param text [String] Link text supplied by RDoc.
  #
  # @return [String] HTML-safe link text.
  def link_text(text)
    @resolve_with_text ? CGI.escapeHTML(text) : text
  end
end

# Prevents RDoc from linking to code objects omitted from Markdown output.
module RDoc::Generator::Markdown::CrossrefExtension
  # Cross-reference adapter scoped to this formatter instance.
  attr_writer :markdown_cross_reference

  # Object IDs emitted by the active Markdown generator.
  attr_writer :markdown_output_object_ids

  # Renders a cross-reference only when its owning object is emitted.
  #
  # @param name [String, nil] Cross-reference target.
  # @param text [String] Visible link text.
  # @param code [Boolean] Whether to format code objects as code.
  # @param rdoc_ref [Boolean] Whether the target uses the rdoc-ref scheme.
  #
  # @return [String] HTML link or unlinked text.
  def link(name, text, code = true, rdoc_ref: false)
    return super unless @markdown_cross_reference

    ref = @markdown_cross_reference.resolve(name, text)
    return super unless RDoc::CodeObject === ref

    context = ref
    context = context.parent until RDoc::ClassModule === context || RDoc::TopLevel === context
    return super if @markdown_output_object_ids.include?(context.object_id)

    text = @markdown_cross_reference.link_text(text)

    return text if RDoc::TopLevel === ref || !code

    "<code>#{text}</code>"
  end
end
