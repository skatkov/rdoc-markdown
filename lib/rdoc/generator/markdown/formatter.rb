# frozen_string_literal: true

require "rdoc/markup/to_markdown"

# Renders comment documents with a native path for standalone code blocks.
class RDoc::Generator::Markdown::Formatter < RDoc::Markup::ToMarkdown
  # Block visitors already emit their required paragraph spacing.
  alias_method :accept_blank_line, :ignore

  # Creates a Markdown visitor with the object's existing RDoc link resolver.
  #
  # @param html_formatter [RDoc::Markup::ToHtmlCrossref] Scoped compatibility formatter.
  # @param heading_level_offset [Integer] Levels to add to comment headings.
  def initialize(html_formatter, heading_level_offset:)
    @html_formatter = html_formatter
    @heading_level_offset = heading_level_offset
    @hard_break = "<br>\n"
  end

  # Resets output and heading IDs for a new document.
  #
  # @return [void]
  def start_accepting
    super
    @html_formatter.start_accepting
  end

  # Visits nested documents, retaining HTML for list and quotation compatibility.
  #
  # @param document [RDoc::Markup::Document] Parsed comment document.
  # @return [void]
  def accept_document(document)
    document.each do |part|
      case part
      when RDoc::Markup::Document
        accept_document(part)
      # shortcut: lists and quotes still use HTML; replace their visitors when migrating nested code blocks.
      when RDoc::Markup::List, RDoc::Markup::BlockQuote
        res << render_html(part) << "\n\n"
      else
        part.accept(self)
      end
    end
  end

  # Preserves RDoc's namespaced and legacy heading anchors.
  #
  # @param heading [RDoc::Markup::Heading] Comment heading.
  # @return [void]
  def accept_heading(heading)
    res << render_html(heading) << "\n\n"
  end

  # Converts embedded HTML using the existing compatibility rules.
  #
  # @param raw [RDoc::Markup::Raw] Raw HTML block.
  # @return [void]
  def accept_raw(raw)
    res << render_html(raw) << "\n\n"
  end

  # Emits code without HTML escaping or syntax-highlighting round trips.
  #
  # @param verbatim [RDoc::Markup::Verbatim] Literal code block.
  # @return [void]
  def accept_verbatim(verbatim)
    text = verbatim.text.rstrip
    language = verbatim.format
    language = "ruby" if verbatim.ruby? || (!language && @html_formatter.parseable?(text))
    res << RDoc::Generator::Markdown::Conversion.verbatim(text, language: language) << "\n\n"
  end

  # Separates native tables from the paragraph that follows them.
  #
  # @param header [Array<String>] Column headings.
  # @param body [Array<Array<String>>] Table rows.
  # @param aligns [Array<Symbol, nil>] Column alignment hints.
  # @return [void]
  def accept_table(header, body, aligns)
    super
    res << "\n"
  end

  # Reuses RDoc's inline cross-reference and escaping behavior.
  #
  # @param text [String] Inline RDoc markup.
  # @return [String] Inline Markdown.
  def attributes(text)
    render_html(RDoc::Markup::Paragraph.new(text))
  end

  # Emits paragraphs without wrapping Markdown links across lines.
  #
  # @param text [String] Inline Markdown.
  # @return [void]
  def wrap(text)
    res << text << "\n\n"
  end

  private

  # GFM needs HTML definition lists; keep RDoc's cross-reference and anchor policies.
  #
  # @param node [Object] RDoc markup node supporting the visitor protocol.
  # @return [String] Compatible Markdown fragment.
  def render_html(node)
    @html_formatter.res.clear
    node.accept(@html_formatter)
    RDoc::Generator::Markdown::Conversion.markdownify(
      @html_formatter.end_accepting,
      heading_level_offset: @heading_level_offset
    )
  end
end
