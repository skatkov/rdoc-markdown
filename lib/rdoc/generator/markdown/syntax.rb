# frozen_string_literal: true

require "cgi"

# Small GFM primitives shared by native markup and the HTML input boundary.
module RDoc::Generator::Markdown::Syntax
  # Escapes literal inline text, including block-looking definition terms.
  # @param text [String] Literal text.
  # @return [String] Safe Markdown text.
  def self.escape(text)
    text.gsub(/[\\`*_\[\]<>#]/) { |character| "\\#{character}" }
      .sub(/\A(\d+)\.(?=\s)/, '\1\\.')
  end

  # Wraps literal code with a delimiter that cannot occur in its contents.
  # @param text [String] Literal code.
  # @return [String] Native code span.
  def self.code(text)
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

  # Indents all continuation blocks beneath their actual list marker.
  # @param marker [String] Bullet or ordered marker.
  # @param body [String] Native block Markdown.
  # @return [String] Indented list item.
  def self.item(marker, body)
    "#{marker} #{body.gsub("\n", "\n#{" " * (marker.length + 1)}")}"
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
