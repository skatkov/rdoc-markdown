# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Native ToMarkdown inline callbacks and explicit-link label boundaries.
  module Inline
    # Escapes plain content without changing inline code or resolved references.
    # @param text [String] Literal content.
    # @return [String] GFM text.
    def convert_string(text)
      Syntax.escape(text)
    end

    # Emits a plain-text node from RDoc's inline parser.
    # @param text [String] Literal content.
    # @return [void]
    def handle_PLAIN_TEXT(text)
      emit_inline(convert_string(text))
    end

    # Emits inline code, resolving only valid reference syntax outside link labels.
    # @param text [String] Literal code.
    # @return [void]
    def handle_TT(text)
      linked = reference_link(text, label: convert_string(text)) if !@in_link && !text.start_with?("@") && reference_pattern.match?(text)
      emit_inline(linked || Syntax.code(text))
    end

    # Emits a tidy link without permitting nested links in its label.
    # @param nodes [Array<String, Hash>] Native inline label nodes.
    # @param url [String] Link target.
    # @return [void]
    def handle_TIDYLINK(nodes, url)
      emit_inline(gen_url(url, dup.inline_nodes(nodes)))
    end

    # Renders a label in an independent native inline buffer.
    # @param nodes [Array<String, Hash>] Native inline label nodes.
    # @return [String] Inline Markdown.
    def inline_nodes(nodes)
      @inline_output = +""
      @in_link = true
      traverse_inline_nodes(nodes)
      @inline_output
    end

    # Indicates the inline-only boundary where nested links are prohibited.
    # @return [Boolean] Whether this visitor renders an explicit link label.
    def in_link_label?
      @in_link
    end

    # Formats native URL schemes and explicit RDoc references.
    # @param url [String] RDoc target.
    # @param label [String] Inline Markdown label.
    # @return [String] Markdown link, image, or unresolved label.
    def gen_url(url, label)
      return explicit_reference(url.delete_prefix("rdoc-ref:"), label) if url.start_with?("rdoc-ref:")
      if url.start_with?("rdoc-label:")
        target, id = url.delete_prefix("rdoc-label:").split(":", 2)
        anchor = id ? Syntax.anchor(id) : ""
        return "#{anchor}#{Syntax.link(label, "##{target}")}"
      end

      _, target, = parse_url(url)
      target = target.sub(/\.(rb|rdoc)(?=[#?]|\z)/i) { "_#{Regexp.last_match(1)}.md" }
      return "![](#{target})" if target.match?(/\Ahttps?:.+\.(?:png|gif|jpe?g|bmp)\z/)

      Syntax.link(label, target)
    end

    private

    # Registers native reference handlers on the markup instance initialized by super.
    # @return [void]
    def configure_inline
      @in_link = false
      @markup.add_regexp_handling(%r{(?:link:|https?://|mailto:|www\.)[^\s<>]+\w}, :HYPERLINK)
      @markup.add_regexp_handling(RDoc::CrossReference::CROSSREF_REGEXP, :CROSSREF)
      @markup.add_regexp_handling(RDoc::CrossReference::ALL_CROSSREF_REGEXP, :CROSSREF) if options.hyperlink_all
    end
  end
end
