# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Native ToMarkdown inline callbacks and explicit-link label boundaries.
  module Inline
    # Escapes plain content without changing inline code or resolved references.
    # @param text [String] Literal content.
    # @return [String] GFM text.
    def convert_string(text)
      # Final definition HTML keeps literal backslashes before semicolons.
      text = text.gsub("\\;") { "\\\\;" } if definition_body
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
      emit_inline(code_reference(text) || Syntax.code(text))
    end

    # Emits a tidy link without permitting nested links in its label.
    # @param nodes [Array<String, Hash>] Native inline label nodes.
    # @param url [String] Link target.
    # @return [void]
    def handle_TIDYLINK(nodes, url)
      first = nodes.first
      label = if nodes.size == 1 && String === first && first.match?(/\A[*^]\d+\z/)
        first[1..]
      else
        dup.inline_nodes(nodes)
      end
      emit_inline(gen_url(url, label))
    end

    # Renders a label in an independent native inline buffer.
    # @param nodes [Array<String, Hash>] Native inline label nodes.
    # @return [String] Inline Markdown.
    def inline_nodes(nodes)
      @inline_output = +""
      @in_link = true
      @quote_converter ||= RDoc::Markup::ToHtml::QuoteConverter.new
      traverse_inline_nodes(nodes)
      @inline_output
    end

    # Uses RDoc's text-only quote policy without routing nodes through ToHtml.
    # @param text [String] Inline RDoc source.
    # @return [String] Inline Markdown with main's punctuation.
    def handle_inline(text)
      @quote_converter = RDoc::Markup::ToHtml::QuoteConverter.new
      @markdown_links = MarkdownLinks.new(text)
      super(@markdown_links.source)
    end

    # Inserts parsed Markdown links without nesting links inside an outer label.
    # @param token [String] Protected Markdown token or literal user input.
    # @return [String] Native Markdown or escaped literal text.
    def handle_regexp_markdown(token)
      link = @markdown_links&.[](token)
      return token unless link

      label = dup.markdown_label(link.label)
      node = link.node
      link_node = node.type == :link
      target = rendering.reference.resolve(node.url) if link_node
      node.url = target.as_href(rendering.context.path) if target && emitted_reference?(target)
      (in_link_label? && link_node) ? label : MarkdownLinks.render(link, label)
    end

    # Parses an original Markdown label with RDoc's surrounding inline semantics.
    # @param text [String] Original link label source.
    # @return [String] Inline Markdown without automatic nested links.
    def markdown_label(text)
      @markdown_links = MarkdownLinks.new(text)
      inline_nodes(RDoc::Markup::InlineParser.new(@markdown_links.source).parse)
    end

    # Preserves the typography aliases used by RDoc's HTML formatter.
    # @param text [String] Matched punctuation or symbol shorthand.
    # @return [String] Unicode punctuation with RDoc's encoding fallback.
    def handle_regexp_HTML_CHARACTERS(text)
      name = RDoc::Markup::ToHtml::HTML_CHARACTER_ALIASES.fetch(text)
      RDoc::Markup::ToHtml::TO_HTML_CHARACTERS[text.encoding].fetch(name)
    end

    # Converts quotes adjacent to words using RDoc's paragraph-scoped state.
    # @param text [String] Matched quote.
    # @return [String] Converted quote or escaped literal.
    def handle_regexp_QUOTE_AFTER_WORD(text)
      @quote_converter.convert(text, after_word: true) || convert_string(text)
    end

    # Converts quotes not adjacent to words using the same paragraph state.
    # @param text [String] Matched quote.
    # @return [String] Converted quote or escaped literal.
    def handle_regexp_QUOTE_NOT_AFTER_WORD(text)
      @quote_converter.convert(text, after_word: false) || convert_string(text)
    end

    # Escapes the visible part after RDoc's selective cross-reference suppression.
    # @param text [String] Suppressed reference prefix.
    # @return [String] Literal Markdown without the suppression backslash.
    def handle_regexp_SUPPRESSED_CROSSREF(text)
      convert_string(text.delete_prefix("\\"))
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
      return label_reference(url, label) if url.start_with?("rdoc-label:")

      _, target, = parse_url(url)
      unless target.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|www\.|#)}i)
        target = target.sub(/\.(rb|rdoc)(?=[#?]|\z)/i) { "_#{Regexp.last_match(1)}.md" }
      end
      return "![](#{target})" if target.match?(/\Ahttps?:.+\.(?:png|gif|jpe?g|bmp)\z/)

      Syntax.link(label, target)
    end

    private

    # Keeps the optional source anchor without parsing HTML attribute strings.
    # @param url [String] Native rdoc-label URL.
    # @param label [String] Inline Markdown label.
    # @return [String] Anchored Markdown reference.
    def label_reference(url, label)
      target, id = url.delete_prefix("rdoc-label:").split(":", 2)
      if id&.start_with?("foot")
        return %(<sup><a id="#{CGI.escapeHTML(id)}" href="##{CGI.escapeHTML(target)}">#{label}</a></sup>)
      end
      anchor = Syntax.anchor(id) if id
      "#{anchor}#{Syntax.link(label, "##{target}")}"
    end

    # Registers native reference handlers on the markup instance initialized by super.
    # @return [void]
    def configure_inline
      @in_link = false
      @markup.add_regexp_handling(/\0RDocMarkdownX*\d+\0/, :markdown)
      # ToRdoc suppresses every backslash escape; main suppresses only references.
      @markup.regexp_handlings.reject! { |_, name| name == :SUPPRESSED_CROSSREF }
      @markup.add_regexp_handling(/\\(?:[#:A-Z]|[a-z]+_[a-z0-9])/, :SUPPRESSED_CROSSREF)
      @markup.add_regexp_handling(/(?:link:|https?:|mailto:|ftp:|irc:|www\.)#{RDoc::Markup::ToHtml::URL_CHARACTERS_REGEXP_STR}+\w/o, :HYPERLINK)
      @markup.add_regexp_handling(Regexp.union(RDoc::Markup::ToHtml::HTML_CHARACTER_ALIASES.keys), :HTML_CHARACTERS)
      @markup.add_regexp_handling(/\b['"`]/, :QUOTE_AFTER_WORD)
      @markup.add_regexp_handling(/\B['"`]/, :QUOTE_NOT_AFTER_WORD)
      @markup.add_regexp_handling(RDoc::CrossReference::CROSSREF_REGEXP, :CROSSREF)
      @markup.add_regexp_handling(RDoc::CrossReference::ALL_CROSSREF_REGEXP, :CROSSREF) if options.hyperlink_all
    end
  end
end
