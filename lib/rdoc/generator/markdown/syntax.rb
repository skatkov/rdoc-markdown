# frozen_string_literal: true

require "cgi"

# Small GFM primitives shared by native markup and the HTML input boundary.
module RDoc::Generator::Markdown::Syntax
  # Collects visible inline text without rendering Markdown through HTML.
  # @param node [Commonmarker::Node] Parsed heading or image label.
  # @return [String] Plain visible text, including soft and hard breaks.
  def self.node_text(node)
    text = +""
    node.walk do |child|
      case child.type
      when :text, :code then text << child.string_content
      when :softbreak, :linebreak then text << " "
      end
    end
    text
  end

  # Collapses HTML prose whitespace and escapes Markdown syntax, not code.
  # @param text [String] Literal prose, including block-looking definition terms.
  # @return [String] Safe Markdown text.
  def self.escape(text)
    text.gsub(/[ \t]+/, " ").gsub(/[&\\`*_\[\]<>#]/) { |character| (character == "&") ? "&amp;" : "\\#{character}" }
      .sub(/\A(\d+)\.(?=\s)/, '\1\\.')
  end

  # Wraps literal code with a delimiter that cannot occur in its contents.
  # @param text [String] Literal code.
  # @return [String] Native code span.
  def self.code(text)
    return "<code></code>" if text.empty?

    fence = ""
    fence += "`" while text.include?(fence)
    content = (text.start_with?("`") || text.end_with?("`")) ? " #{text} " : text
    "#{fence}#{content}#{fence}"
  end

  # Emits fenced code without interpreting its contents as prose.
  # @param text [String] Literal code.
  # @param language [String, Symbol, nil] Optional language metadata.
  # @return [String] Fenced code block.
  def self.code_block(text, language)
    fence = "```"
    fence += "`" while text.include?(fence)
    "#{fence}#{language}\n#{text.rstrip}\n#{fence}"
  end

  # Emits an explicit, attribute-safe heading alias.
  # @param id [String] Fragment identifier.
  # @return [String] Empty HTML anchor.
  def self.anchor(id)
    %(<a id="#{CGI.escapeHTML(id)}"></a>)
  end

  # Formats a GFM heading and its explicit aliases.
  # @param level [Integer] Requested heading level.
  # @param text [String] Native inline Markdown.
  # @param aliases [Array<String>] Additional heading IDs.
  # @return [String] Heading capped at level six.
  def self.heading(level, text, aliases)
    "#{"#" * [level, 6].min} #{text}#{aliases.map { |id| anchor(id) }.join}"
  end

  # Maps legacy local HTML targets while preserving external URLs and fragments.
  # @param href [String] Original target.
  # @return [String] Markdown target.
  def self.target(href)
    return "https://#{href}" if href.start_with?("www.")
    return href if href.match?(/\A(?:https?:\/\/|mailto:|#)/i)

    href.sub(/\.html(?=[?#]|\z)/i, ".md")
      .sub(%r{\A/(?=.+\.md(?:[?#]|\z))}, "")
      .sub(%r{\A((?:\.\./)*)(?:files|classes|modules)/(?=.+\.md(?:[?#]|\z))}, '\1')
  end

  # Emits a link, restoring Ruby indexing expressions misparsed as tidy links.
  # @param label [String] Native inline Markdown label.
  # @param href [String] Original target.
  # @return [String] Markdown link or literal code span.
  def self.link(label, href)
    receiver = label.delete("\\")
    if receiver.match?(/\A(?:[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*|[a-z_][A-Za-z0-9_]*)\z/) &&
        href.match?(/\A(?::.+|".+")\z/)
      code("#{receiver}[#{href}]")
    else
      "[#{label}](#{target(href)})"
    end
  end
end
