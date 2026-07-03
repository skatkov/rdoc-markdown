# frozen_string_literal: true

# Preserves simple <pre class="ruby"> language metadata emitted by RDoc.
class ReverseMarkdown::Converters::RDocMarkdownPre < ReverseMarkdown::Converters::Pre
  LANGUAGE_CLASS = /\A(?!highlight\z)[A-Za-z][A-Za-z0-9_+-]*\z/

  def convert(node, *)
    content = treat_children(rdoc_pre_node(node), {})
    "\n```#{language(node)}\n" << content << "\n```\n"
  end

  private

  def rdoc_pre_node(node)
    Nokogiri::HTML.fragment("<pre>#{node.text}</pre>").at("pre")
  end

  def language(node)
    node["class"].to_s[LANGUAGE_CLASS] || super
  end
end

ReverseMarkdown::Converters.register :pre, ReverseMarkdown::Converters::RDocMarkdownPre.new
