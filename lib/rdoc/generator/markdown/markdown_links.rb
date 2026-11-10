# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Protects Markdown links while RDoc parses the surrounding inline markup.
  class MarkdownLinks
    # Both the parsed target and original RDoc label are needed at the boundary.
    Link = Data.define(:node, :label)

    # RDoc source with collision-free link tokens instead of Markdown link syntax.
    # @return [String] Prepared inline RDoc source.
    attr_reader :source

    # Finds complete Markdown links without interpreting RDoc code tags as prose.
    # @param text [String] Original inline RDoc source.
    def initialize(text)
      @source = text
      @nodes = {}
      return unless text.include?("](")

      @source = text.encode(Encoding::UTF_8)
      @line_offsets = [0]
      @source.each_line { |line| @line_offsets << @line_offsets.last + line.bytesize }
      @literal_ranges = literal_ranges
      buffer = @source.b
      link_edits.reverse_each { |range, token| buffer[range] = token }
      @source = buffer.force_encoding(Encoding::UTF_8)
    end

    # Looks up only tokens created for this exact input.
    # @param token [String] Inline parser token.
    # @return [Link, nil] Parsed Markdown link and its original label.
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

    # Uses source byte positions; links inside outer links/images stay together.
    # @return [Array<Array(Range, String)>] Nonoverlapping source replacements.
    def link_edits
      prefix = "RDocMarkdown"
      prefix += "X" while @source.include?(prefix)
      edits = []
      covered_until = nil
      Commonmarker.parse(@source).walk do |node|
        range = link_range(node)
        next if !range || (covered_until && range.begin < covered_until)

        token = "\0#{prefix}#{@nodes.length}\0"
        @nodes[token] = Link.new(node, original_label(node))
        edits << [range, token]
        covered_until = range.end
      end
      edits
    end

    # Keeps native RDoc links and literal code ahead of Markdown interpretation.
    # @param node [Commonmarker::Node] Candidate Markdown node.
    # @return [Range<Integer>, nil] Replaceable Markdown link source range.
    def link_range(node)
      type = node.type
      return unless [:link, :image].include?(type)

      range = source_range(node)
      first = range.begin
      bytes = @source.b
      return unless bytes[range].start_with?("[", "![")

      previous = bytes[first - 1] unless first.zero?
      return if type == :link && previous&.match?(/[A-Za-z0-9}]/)
      return if @literal_ranges.any? { |literal| literal.cover?(first) }

      range
    end

    # Maps Commonmarker's one-based UTF-8 byte columns to Ruby byte ranges.
    # @param node [Commonmarker::Node] Parsed node with source positions.
    # @return [Range<Integer>] Half-open source byte range.
    def source_range(node)
      start_line, start_column, end_line, end_column = node.source_position.fetch_values(:start_line, :start_column, :end_line, :end_column)
      first = @line_offsets.fetch(start_line - 1) + start_column - 1
      last = @line_offsets.fetch(end_line - 1) + end_column
      first...last
    end

    # Retains RDoc label formatting instead of changing its emphasis conventions.
    # @param node [Commonmarker::Node] Markdown link or image.
    # @return [String] Label source, including native formatting delimiters.
    def original_label(node)
      children = node.to_a
      return "" if children.empty?

      range = source_range(children.first).begin...source_range(children.last).end
      @source.b[range].force_encoding(Encoding::UTF_8)
    end

    # These are RDoc's code-tag/escape rules, not a second Markdown link parser.
    # @return [Array<Range<Integer>>] Literal native RDoc code spans.
    def literal_ranges
      ranges = []
      @source.b.scan(/\\[\\*_+`{}\[\]<>]|<(code|tt)>(?:\\.|[^\\])*?<\/\1>/) do
        ranges << Range.new(*Regexp.last_match.offset(0), true)
      end
      ranges
    end
  end
end
