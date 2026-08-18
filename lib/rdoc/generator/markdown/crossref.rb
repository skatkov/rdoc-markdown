# frozen_string_literal: true

# Prevents RDoc from linking to code objects omitted from Markdown output.
module RDoc::Generator::Markdown::CrossrefExtension
  # Applies Markdown cross-reference state while rendering a description.
  #
  # @param cross_reference [RDoc::CrossReference] Resolver scoped to the formatter.
  # @param output_object_ids [Set<Integer>] Object IDs emitted by the generator.
  #
  # @return [Object] Value returned by the block.
  def with_markdown_cross_references(cross_reference, output_object_ids)
    @markdown_cross_reference = cross_reference
    @markdown_output_object_ids = output_object_ids
    yield
  ensure
    @markdown_cross_reference = nil
  end

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

    ref = @markdown_cross_reference.resolve(name) if name
    return super unless RDoc::CodeObject === ref

    context = ref
    context = context.parent until RDoc::ClassModule === context || RDoc::TopLevel === context
    return super if @markdown_output_object_ids.include?(context.object_id)

    return text if RDoc::TopLevel === ref || !code

    "<code>#{text}</code>"
  end
end
