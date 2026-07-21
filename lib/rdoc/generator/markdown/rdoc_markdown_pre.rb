# frozen_string_literal: true

# Preserves simple <pre class="ruby"> language metadata emitted by RDoc.
class ReverseMarkdown::Converters::RDocMarkdownPre < ReverseMarkdown::Converters::Pre
  # Matches RDoc's plain language class names on pre blocks.
  LANGUAGE_CLASS = /\A(?!highlight\z)[A-Za-z][A-Za-z0-9_+-]*\z/

  # Converts an RDoc pre block into a GitHub-flavored Markdown fence.
  #
  # @param node [Nokogiri::XML::Node] RDoc pre node.
  # @param _state [Hash] reverse_markdown converter state.
  #
  # @return [String] Markdown code fence.
  def convert(node, _state)
    content = treat_children(rdoc_pre_node(node), {})
    "\n```#{language(node)}\n" << content << "\n```\n"
  end

  private

  # Rebuilds a plain pre node from RDoc-highlighted text.
  #
  # @param node [Nokogiri::XML::Node] RDoc pre node.
  #
  # @return [Nokogiri::XML::Node] Plain pre node.
  def rdoc_pre_node(node)
    Nokogiri::HTML.fragment("<pre>#{node.text}</pre>").at("pre")
  end

  # Extracts the Markdown fence language.
  #
  # @param node [Nokogiri::XML::Node] RDoc pre node.
  #
  # @return [String, nil] Language name, or nil when no language is known.
  def language(node)
    node["class"].to_s[LANGUAGE_CLASS] || super
  end
end

# Retains the backward-compatible heading aliases emitted by RDoc.
class ReverseMarkdown::Converters::RDocMarkdownSpan < ReverseMarkdown::Converters::Bypass
  # Converts an RDoc legacy anchor into Markdown-compatible HTML.
  #
  # @param node [Nokogiri::XML::Node] HTML span node.
  # @param _state [Hash] reverse_markdown converter state.
  #
  # @return [String] Converted span content or an anchor alias.
  def convert(node, _state)
    return %(<a id="#{node["id"]}"></a>) if node["class"] == "legacy-anchor"

    super
  end
end

# Flattens RDoc heading self-links while retaining non-GitHub anchor aliases.
class ReverseMarkdown::Converters::RDocMarkdownHeading < ReverseMarkdown::Converters::H
  # Converts an RDoc heading into Markdown without its generated self-link.
  #
  # @param node [Nokogiri::XML::Node] HTML heading node.
  # @param state [Hash] reverse_markdown converter state.
  #
  # @return [String] Markdown heading.
  def convert(node, state = {})
    link = node.xpath("./a[starts-with(@href, '#') and string-length(@href) > 1]").find do |anchor|
      anchor.text.match?(/\S/) &&
        anchor.xpath("preceding-sibling::node()").none? { |sibling| sibling.text.match?(/\S/) }
    end
    return super unless link

    id = link["href"].delete_prefix("#")
    link.replace(link.children)

    unless id == RDoc::Text.to_anchor(node.text)
      alias_anchor = node.document.create_element("span", "class" => "legacy-anchor", "id" => id)
      node.add_child(alias_anchor)
    end

    super
  end
end

# Converts RDoc indexing expressions and scheme-less web links structurally.
class ReverseMarkdown::Converters::RDocMarkdownAnchor < ReverseMarkdown::Converters::A
  # Converts an HTML anchor into Markdown or an indexing expression.
  #
  # @param node [Nokogiri::XML::Node] HTML anchor node.
  # @param state [Hash] reverse_markdown converter state.
  #
  # @return [String] Markdown link or inline code.
  def convert(node, state = {})
    receiver = node.text
    href = node["href"].to_s

    if receiver.match?(/\A[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*\z/) && href.match?(/\A(?::.+|".+")\z/)
      "`#{receiver}[#{href}]`"
    else
      node["href"] = "https://#{href}" if href.start_with?("www.")
      super
    end
  end
end

ReverseMarkdown::Converters.register :pre, ReverseMarkdown::Converters::RDocMarkdownPre.new
ReverseMarkdown::Converters.register :span, ReverseMarkdown::Converters::RDocMarkdownSpan.new
ReverseMarkdown::Converters.register :a, ReverseMarkdown::Converters::RDocMarkdownAnchor.new
ReverseMarkdown::Converters.register :h1, ReverseMarkdown::Converters::RDocMarkdownHeading.new
ReverseMarkdown::Converters.register :h2, ReverseMarkdown::Converters::RDocMarkdownHeading.new
ReverseMarkdown::Converters.register :h3, ReverseMarkdown::Converters::RDocMarkdownHeading.new
ReverseMarkdown::Converters.register :h4, ReverseMarkdown::Converters::RDocMarkdownHeading.new
ReverseMarkdown::Converters.register :h5, ReverseMarkdown::Converters::RDocMarkdownHeading.new
ReverseMarkdown::Converters.register :h6, ReverseMarkdown::Converters::RDocMarkdownHeading.new
