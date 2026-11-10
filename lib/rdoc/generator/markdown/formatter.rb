# frozen_string_literal: true

require "rdoc/markup/to_markdown"
require "prism"
require_relative "inline"
require_relative "blocks"

class RDoc::Generator::Markdown
  # One native visitor with separate block, inline, and reference responsibilities.
  class Formatter < RDoc::Markup::ToMarkdown
    include References
    include Inline
    include Blocks

    # Context shared by child visitors; each child owns its native output buffer.
    Rendering = Data.define(:object, :context, :reference, :output_ids, :heading_offset, :heading_ids)

    # Immutable render configuration and document-scoped heading IDs.
    # @return [Rendering] Current document context.
    attr_reader :rendering

    # Block visitors emit their own paragraph spacing.
    alias_method :accept_blank_line, :ignore

    # Initializes the native formatter and its document-scoped references.
    # @param code_object [RDoc::CodeObject, RDoc::Context::Section] Described object.
    # @param output_object_ids [Set<Integer>] Emitted objects.
    # @param heading_level_offset [Integer] Levels to add to comment headings.
    def initialize(code_object, output_object_ids:, heading_level_offset:)
      super()
      context = (RDoc::Context === code_object) ? code_object : code_object.parent
      @rendering = Rendering.new(code_object, context, RDoc::CrossReference.new(context), output_object_ids, heading_level_offset, Hash.new(0))
      @from_path = context.path
      configure_inline
    end
  end
end
