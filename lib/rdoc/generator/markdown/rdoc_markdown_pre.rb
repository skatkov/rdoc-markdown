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

ReverseMarkdown::Converters.register :pre, ReverseMarkdown::Converters::RDocMarkdownPre.new
ReverseMarkdown::Converters.register :span, ReverseMarkdown::Converters::RDocMarkdownSpan.new
