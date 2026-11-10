# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Explicit HTML input boundary; never used to render native RDoc nodes.
  class HtmlInput
    # Native delimiters for the inline HTML tags accepted at this boundary.
    INLINE_MARKERS = {"strong" => "**", "b" => "**", "em" => "*", "i" => "*", "del" => "~~", "s" => "~~"}.freeze

    # Creates an adapter with the surrounding comment's heading offset.
    # @param heading_level_offset [Integer] Levels to add to HTML headings.
    def initialize(heading_level_offset:)
      @heading_level_offset = heading_level_offset
    end

    # Preserves HTML-only constructs and adapts supported elements to native GFM.
    # @param html [String] Explicit raw HTML input.
    # @return [String] Markdown fragment.
    def render(html)
      fragment = Nokogiri::HTML.fragment(html)
      fragment.css("span.legacy-anchor[id]").each { |span| position_anchor(span) }
      nodes = fragment.children.reject { |node| node.text? && !node.text.match?(/\S/) }
      render_nodes(nodes).strip
    end

    private

    # Keeps legacy spans beside their heading without exposing context aliases.
    # @param span [Nokogiri::XML::Element] Legacy anchor.
    # @return [void]
    def position_anchor(span)
      heading = span.next_element
      if heading&.name == "h1" && span["id"].match?(/\A(?:class|module)-/)
        span.remove
      elsif heading&.name&.match?(/\Ah[1-6]\z/)
        heading.add_child(span)
      end
    end

    # Formats adjacent input nodes without reparsing emitted Markdown.
    # @param nodes [Nokogiri::XML::NodeSet] Input siblings.
    # @return [String] Native Markdown.
    def render_nodes(nodes)
      nodes.map { |node| render_node(node) }.join
    end

    # Dispatches explicit HTML blocks and native inline primitives.
    # @param node [Nokogiri::XML::Node] HTML input node.
    # @return [String] Native Markdown or preserved raw HTML.
    def render_node(node)
      return text_node(node) if node.text?

      case node.name
      when "p" then paragraph(node)
      when /\Ah[1-6]\z/ then heading(node)
      when "pre" then preformatted(node)
      when "code", "tt" then Syntax.code(node.text)
      when "br" then "<br>"
      when *INLINE_MARKERS.keys, "a", "span", "div" then inline_element(node)
      else preserve_html(node)
      end
    end

    # Escapes literal HTML text without changing preformatted code.
    # @param node [Nokogiri::XML::Text] Literal text.
    # @return [String] Native inline Markdown.
    def text_node(node)
      Syntax.escape(node.text.tr("\n", " "))
    end

    # Separates paragraphs from preceding standalone anchor spans.
    # @param node [Nokogiri::XML::Element] Paragraph element.
    # @return [String] Paragraph Markdown.
    def paragraph(node)
      prefix = "\n\n" if node.previous_element&.name == "span"
      "#{prefix}#{render_nodes(node.children)}\n\n"
    end

    # Reads supported language metadata without interpreting the code itself.
    # @param node [Nokogiri::XML::Element] Preformatted element.
    # @return [String, nil] Explicit language metadata.
    def code_language(node)
      css = node["class"].to_s
      css[/\A(?!highlight\z)[A-Za-z][A-Za-z0-9_+-]*\z/] ||
        css[/\Abrush: (\w+);\z/, 1] || node.parent["class"].to_s[/\Ahighlight-(\w+)\z/, 1]
    end

    # Keeps literal indentation while removing the conventional opening newline.
    # @param node [Nokogiri::XML::Element] Preformatted HTML input.
    # @return [String] Native fenced code.
    def preformatted(node)
      "#{Syntax.code_block(node.text.delete_prefix("\n"), code_language(node))}\n\n"
    end

    # Converts only known inline tags, preserving explicit anchor identities.
    # @param node [Nokogiri::XML::Element] Inline or transparent container.
    # @return [String] Inline Markdown.
    def inline_element(node)
      name = node.name
      content = render_nodes(node.children)
      marker = INLINE_MARKERS[name]
      return "#{marker}#{content}#{marker}" if marker

      id = node["id"]
      link = name == "a"
      return Syntax.anchor(id) if id && (link || node["class"] == "legacy-anchor")
      return content unless link

      href = node["href"]
      href ? Syntax.link(content, href) : content
    end

    # Leaves unsupported HTML intact while mapping its actual link targets.
    # @param node [Nokogiri::XML::Element] HTML-only construct.
    # @return [String] Preserved HTML block.
    def preserve_html(node)
      node.css("a[href]").each { |link| link["href"] = Syntax.target(link["href"]) }
      "#{node}\n\n"
    end

    # Flattens leading heading self-links and retains their noncanonical aliases.
    # @param node [Nokogiri::XML::Element] Heading element.
    # @return [String] Native Markdown heading.
    def heading(node)
      spans = node.css("span.legacy-anchor[id]")
      aliases = spans.map { |span| span["id"] }
      spans.remove
      first = node.element_children.first
      href = first&.[]("href").to_s
      if first&.name == "a" && href.match?(/\A#./) &&
          first.text.match?(/\S/) && first.xpath("preceding-sibling::node()").none? { |sibling| sibling.text.match?(/\S/) }
        id = href.delete_prefix("#")
        first.replace(first.children)
        aliases << id unless id == RDoc::Text.to_anchor(node.text)
      end
      text = render_nodes(node.children).strip
      "#{Syntax.heading(Integer(node.name.delete_prefix("h")) + @heading_level_offset, text, aliases)}\n\n"
    end
  end
end
