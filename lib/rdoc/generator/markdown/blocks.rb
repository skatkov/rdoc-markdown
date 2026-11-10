# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Native block visitors; nested fragments share context, not output buffers.
  module Blocks
    # Visits nested documents and lists without resetting document state.
    #
    # @param document [RDoc::Markup::Document] Parsed comment document.
    # @return [void]
    def accept_document(document)
      document.each do |part|
        case part
        when RDoc::Markup::Document
          accept_document(part)
        when RDoc::Markup::List
          accept_list(part)
        else
          part.accept(self)
        end
      end
    end

    # Renders list contents natively, including code inside definition lists.
    #
    # @param list [RDoc::Markup::List] Parsed list.
    # @return [void]
    def accept_list(list)
      type = list.type
      unless [:BULLET, :NUMBER, :LALPHA, :UALPHA, :LABEL, :NOTE].include?(type)
        raise RDoc::Error, "Invalid list type: #{type.inspect}"
      end

      items = list.items.each_with_index.map { |item, index| list_item(type, item, index) }.join("\n")
      if [:LABEL, :NOTE].include?(type)
        res << %(<dl class="rdoc-list #{type.downcase}-list">\n\n#{items}</dl>\n\n)
      else
        res << items << "\n\n"
      end
    end

    # Quotes every line, preserving nested blocks and literal code.
    #
    # @param quote [RDoc::Markup::BlockQuote] Quoted markup nodes.
    # @return [void]
    def accept_block_quote(quote)
      res << render_parts(quote.parts).lines.map { |line| "> #{line}" } << "\n\n"
    end

    # Preserves RDoc's namespaced and legacy heading anchors.
    #
    # @param heading [RDoc::Markup::Heading] Comment heading.
    # @return [void]
    def accept_heading(heading)
      aliases = heading_aliases(heading)
      text = attributes(heading.text)
      text = text.sub(/\A\[([^\]]+)\]\((#[^)]+)\)/) do
        target = Regexp.last_match(2).delete_prefix("#")
        aliases << target unless target == heading.aref
        Regexp.last_match(1)
      end
      res << Syntax.heading(heading.level + rendering.heading_offset, text, aliases.uniq) << "\n\n"
    end

    # Converts embedded HTML using the existing compatibility rules.
    #
    # @param raw [RDoc::Markup::Raw] Raw HTML block.
    # @return [void]
    def accept_raw(raw)
      res << HtmlInput.new(heading_level_offset: rendering.heading_offset).render(raw.parts.join("\n")) << "\n\n"
    end

    # Emits code without HTML escaping or syntax-highlighting round trips.
    #
    # @param verbatim [RDoc::Markup::Verbatim] Literal code block.
    # @return [void]
    def accept_verbatim(verbatim)
      text = verbatim.text
      language = verbatim.format
      language = "ruby" if verbatim.ruby? || (!language && Prism.parse_success?(text))
      res << Syntax.code_block(text, language) << "\n\n"
    end

    # Separates native tables from the paragraph that follows them.
    #
    # @param header [Array<String>] Column headings.
    # @param body [Array<Array<String>>] Table rows.
    # @param aligns [Array<Symbol, nil>] Column alignment hints.
    # @return [void]
    def accept_table(header, body, aligns)
      rows = [header, *body].map { |row| table_row(row) }
      rows.insert(1, aligns.map { "---" })
      res << rows.map { |row| "| #{row.join(" | ")} |\n" } << "\n"
    end

    # Preserves RDoc's language-aware soft breaks and explicit hard breaks.
    # @param paragraph [RDoc::Markup::Paragraph] Parsed paragraph.
    # @return [void]
    def accept_paragraph(paragraph)
      text = paragraph.text("<br>\n")
      text = text.gsub(/(#{RDoc::Text::SPACE_SEPARATED_LETTER_CLASS})?\K(?:\r?\n)+(?=(?(1)(#{RDoc::Text::SPACE_SEPARATED_LETTER_CLASS})?))/o) { defined?($2) && " " }
      wrap(attributes(text))
    end

    # Emits paragraphs without wrapping Markdown links across lines.
    #
    # @param text [String] Inline Markdown.
    # @return [void]
    def wrap(text)
      res << text << "\n\n"
    end

    private

    # Indents continuation blocks by the width of their actual list marker.
    #
    # @param type [Symbol] RDoc list type.
    # @param item [RDoc::Markup::ListItem] Item containing native markup nodes.
    # @param index [Integer] Zero-based item index.
    # @return [String] Markdown list item or HTML definition container.
    def list_item(type, item, index)
      body = render_parts(item.parts)
      return definition_item(item.label, body) if [:LABEL, :NOTE].include?(type)

      marker = (type == :BULLET) ? "-" : "#{index + 1}."
      Syntax.item(marker, body)
    end

    # Blank lines allow GFM to parse native Markdown inside definition containers.
    #
    # @param label [String, Array<String>, nil] Definition terms.
    # @param body [String] Native Markdown for the description.
    # @return [String] Definition item with Markdown-enabled HTML boundaries.
    def definition_item(label, body)
      terms = Array(label).map { |term| "<dt>\n\n#{attributes(term)}\n\n</dt>\n" }.join
      "#{terms}<dd>\n\n#{body}\n\n</dd>\n\n"
    end

    # Renders nested blocks without resetting shared heading IDs or cross-references.
    #
    # @param parts [Array<Object>] Child markup nodes.
    # @return [String] Nested Markdown.
    def render_parts(parts)
      RDoc::Markup::Document.new(*parts).accept(dup).rstrip
    end

    # Formats table cells in their own inline escaping context.
    # @param cells [Array<String>] RDoc cell contents.
    # @return [Array<String>] GFM-safe cells.
    def table_row(cells)
      cells.map { |cell| attributes(cell).gsub("|", '\\|') }
    end

    # Computes compatible heading aliases from RDoc's canonical label methods.
    # @param heading [RDoc::Markup::Heading] Parsed heading.
    # @return [Array<String>] Legacy and namespaced IDs.
    def heading_aliases(heading)
      object = rendering.object
      modern = unique_heading_id(heading.label(object))
      legacy = unique_heading_id(heading.legacy_label(object))
      aliases = []
      aliases << legacy unless RDoc::ClassModule === object && heading.level == 1
      aliases << modern unless modern == heading.aref
      aliases
    end

    # Deduplicates IDs across the document and its native child visitors.
    # @param id [String] RDoc heading ID.
    # @return [String] Unique heading ID.
    def unique_heading_id(id)
      ids = rendering.heading_ids
      count = ids[id]
      ids[id] = count + 1
      count.zero? ? id : "#{id}-#{count}"
    end
  end
end
