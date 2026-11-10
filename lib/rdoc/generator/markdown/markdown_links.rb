# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Protects Markdown links and tag-like code while RDoc parses surrounding markup.
  class MarkdownLinks
    # Keeps the typed node and original RDoc label together at the boundary.
    Link = Data.define(:node, :label)

    # RDoc source with collision-free tokens protecting Markdown links and code.
    # @return [String] Prepared inline RDoc source.
    attr_reader :source

    # Finds complete Markdown links without interpreting RDoc code tags as prose.
    # @param text [String] Original inline RDoc source.
    def initialize(text)
      @source = text
      @nodes = {}
      return if !(text.include?("](") || (text.include?("`") && text.include?("<")))

      @source = text.encode(Encoding::UTF_8)
      @line_offsets = [0]
      @source.each_line { |line| @line_offsets << @line_offsets.last + line.bytesize }
      @literal_ranges = Syntax.native_literal_ranges(@source)
      buffer = @source.b
      inline_edits.reverse_each { |range, token| buffer[range] = token }
      @source = buffer.force_encoding(Encoding::UTF_8)
    end

    # Looks up only tokens created for this exact input.
    # @param token [String] Inline parser token.
    # @return [Link, nil] Protected Markdown node and its original label.
    def [](token)
      @nodes[token]
    end

    # Serializes a typed link, retaining titles and destination escaping.
    # @param link [Link] Original link or image node.
    # @param label [String] Natively formatted inline Markdown label.
    # @return [String] Inline Markdown, never rendered HTML.
    def self.render(link, label)
      original = link.node
      prefix = "!" if original.type == :image
      node = Commonmarker.parse("#{prefix}[#{label}](markdown-target)").first_child.first_child
      node.url = Syntax.target(original.url)
      node.title = original.title
      node.to_commonmark.delete_suffix("\n")
    end

    private

    # Uses source byte positions; inline nodes inside outer links stay together.
    # @return [Array<Array(Range, String)>] Nonoverlapping source replacements.
    def inline_edits
      prefix = "RDocMarkdown"
      prefix += "X" while @source.include?(prefix)
      edits = []
      covered_until = nil
      Commonmarker.parse(@source).walk do |node|
        range = inline_range(node)
        next if !range || (covered_until && range.begin < covered_until)

        token = "\0#{prefix}#{@nodes.length}\0"
        @nodes[token] = Link.new(node, original_label(node))
        edits << [range, token]
        covered_until = range.end
      end
      edits
    end

    # Keeps native RDoc links and code-tag boundaries ahead of Markdown spans.
    # @param node [Commonmarker::Node] Candidate Markdown node.
    # @return [Range<Integer>, nil] Replaceable Markdown link or tag-like code range.
    def inline_range(node)
      type = node.type
      return unless [:link, :image, :code].include?(type)
      return if type == :code && !node.string_content.include?("<")

      range = Syntax.source_range(node, @line_offsets)
      first = range.begin
      bytes = @source.b
      return unless bytes[range].start_with?("[", "![", "`")

      previous = bytes[first - 1] unless first.zero?
      return if type == :link && previous&.match?(/[A-Za-z0-9}]/)
      return if Syntax.literal_position?(@literal_ranges, first)

      range
    end

    # Retains RDoc label formatting instead of changing its emphasis conventions.
    # @param node [Commonmarker::Node] Markdown link or image.
    # @return [String] Label source, including native formatting delimiters.
    def original_label(node)
      children = node.to_a
      return "" if children.empty?

      range = Syntax.source_range(children.first, @line_offsets).begin...Syntax.source_range(children.last, @line_offsets).end
      @source.b[range].force_encoding(Encoding::UTF_8)
    end
  end
end
