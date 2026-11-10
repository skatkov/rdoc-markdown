# frozen_string_literal: true

require "cgi"

# Small GFM primitives shared by native markup and the HTML input boundary.
module RDoc::Generator::Markdown::Syntax
  # Maps Commonmarker's one-based UTF-8 byte columns to Ruby byte ranges.
  # @param node [Commonmarker::Node] Parsed node with source positions.
  # @param offsets [Array<Integer>] Byte offset of each source line.
  # @return [Range<Integer>] Half-open source byte range.
  def self.source_range(node, offsets)
    start_line, start_column, end_line, end_column = node.source_position.fetch_values(:start_line, :start_column, :end_line, :end_column)
    first = offsets.fetch(start_line - 1) + start_column - 1
    last = offsets.fetch(end_line - 1) + end_column
    first...last
  end

  # Uses RDoc's code-tag and escape rules to identify literal native source.
  # @param text [String] Original inline source.
  # @return [Array<Range<Integer>>] Literal native source byte ranges.
  def self.native_literal_ranges(text)
    ranges = []
    text.b.scan(/\\[\\*_+`{}\[\]<>]|<(code|tt)>(?:\\.|[^\\])*?<\/\1>/) do
      ranges << Range.new(*Regexp.last_match.offset(0), true)
    end
    ranges
  end

  # Protects native code tags and Markdown code spans during prose cleanup.
  # @param text [String] Inline source encoded as UTF-8.
  # @return [Array<Range<Integer>>] Literal source byte ranges.
  def self.code_ranges(text)
    offsets = [0]
    text.each_line { |line| offsets << offsets.last + line.bytesize }
    ranges = native_literal_ranges(text)
    Commonmarker.parse(text).walk do |node|
      ranges << source_range(node, offsets) if node.type == :code
    end
    ranges
  end

  # Checks a byte position against protected source spans.
  # @param ranges [Array<Range<Integer>>] Literal source ranges.
  # @param position [Integer] Source byte offset.
  # @return [Boolean] Whether the position is inside literal content.
  def self.literal_position?(ranges, position)
    ranges.any? { |range| range.cover?(position) }
  end

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

  # Escapes prose while retaining main's Markdown escape for semicolons.
  # @param text [String] Literal prose, including block-looking definition terms.
  # @return [String] Safe Markdown text.
  def self.escape(text)
    text.gsub(/[ \t]+/, " ").gsub(/[&`*_\[\]<>#]|\\(?!;)/) { |character| (character == "&") ? "&amp;" : "\\#{character}" }
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
