# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Emits final inline HTML inside definition containers, without HTML conversion.
  class InlineHtml
    # Native inline formatting tags; transparent AST containers have no wrapper.
    TAGS = {document: nil, paragraph: nil, escaped: nil, emph: "em", strong: "strong", strikethrough: "del"}.freeze

    # Serializes only inline syntax already produced by the native formatter.
    # @param markdown [String] Escaped native inline Markdown.
    # @return [String] Final inline HTML, with no paragraph wrapper.
    def self.render(markdown)
      new.render_node(Commonmarker.parse(markdown.encode(Encoding::UTF_8), options: {extension: {autolink: false}}))
    end

    # Emits one parsed inline node and its children.
    # @param node [Commonmarker::Node] Native inline syntax node.
    # @return [String] Final inline HTML.
    def render_node(node)
      type = node.type
      case type
      when :text, :code
        text = CGI.escapeHTML(node.string_content)
        (type == :code) ? "<code>#{text}</code>" : text
      when :html_inline then node.to_commonmark.delete_suffix("\n")
      when :softbreak then "\n"
      when :linebreak then "<br>\n"
      when :image then image(node)
      else
        content = node.map { |child| render_node(child) }.join
        return %(<a href="#{CGI.escapeHTML(node.url)}"#{title(node)}>#{content}</a>) if type == :link

        tag = TAGS.fetch(type)
        tag ? "<#{tag}>#{content}</#{tag}>" : content
      end
    end

    private

    # An image's alt text is plain text, including formatted labels' contents.
    # @param node [Commonmarker::Node] Image node.
    # @return [String] Final image HTML.
    def image(node)
      alt = Syntax.node_text(node)
      %(<img src="#{CGI.escapeHTML(node.url)}" alt="#{CGI.escapeHTML(alt)}"#{title(node)}>)
    end

    # Escapes optional titles independently from the link or image destination.
    # @param node [Commonmarker::Node] Link or image node.
    # @return [String] Optional HTML title attribute.
    def title(node)
      value = node.title
      %( title="#{CGI.escapeHTML(value)}") unless value.empty?
    end
  end
end
