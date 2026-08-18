# frozen_string_literal: true

# Converts RDoc HTML and normalizes generated Markdown.
module RDoc::Generator::Markdown::Conversion
  private

  # Converts RDoc HTML into GitHub-flavored Markdown.
  #
  # @param input [String] RDoc HTML fragment.
  #
  # @return [String] Markdown with normalized links and no trailing whitespace.
  def markdownify(input)
    fragment = normalized_html_fragment(input)
    anchor_aliases = tokenize_legacy_anchors(fragment.css("span.legacy-anchor[id]"))
    normalize_links(fragment)
    markdown = reverse_markdown(fragment)
    restore_anchor_aliases(markdown, anchor_aliases)
    normalize_definition_list_code_blocks(markdown).rstrip
  end

  # Short alias used by ERB templates.
  alias_method :h, :markdownify

  # Normalizes HTML constructs that reverse_markdown cannot preserve directly.
  #
  # @param input [String] RDoc HTML fragment.
  #
  # @return [Nokogiri::HTML4::DocumentFragment] Normalized fragment.
  def normalized_html_fragment(input)
    fragment = Nokogiri::HTML.fragment(input)
    context_anchors, content_anchors = fragment.css("span.legacy-anchor[id]").partition do |span|
      context_anchor?(span)
    end
    context_anchors.each(&:remove)
    move_legacy_anchors_into_headings(content_anchors)
    normalize_pre_blocks(fragment)
    normalize_heading_links(fragment)
    fragment
  end

  # Checks whether an anchor identifies the surrounding class or module.
  #
  # @param span [Nokogiri::XML::Element] Legacy anchor span.
  #
  # @return [Boolean] Whether the anchor belongs to a top-level context heading.
  def context_anchor?(span)
    span.next_element&.name == "h1" && span["id"].match?(/\A(?:class|module)-/)
  end

  # Moves standalone legacy anchors into the following heading.
  #
  # @param anchors [Array<Nokogiri::XML::Element>] Legacy anchor spans.
  #
  # @return [void]
  def move_legacy_anchors_into_headings(anchors)
    anchors.each do |span|
      heading = span.next_element
      heading.add_child(span) if heading&.name&.match?(/\Ah[1-6]\z/)
    end
  end

  # Preserves simple language classes and literal preformatted text.
  #
  # @param fragment [Nokogiri::HTML4::DocumentFragment] HTML fragment.
  #
  # @return [void]
  def normalize_pre_blocks(fragment)
    fragment.css("pre").each do |pre|
      language = pre["class"].to_s[/\A(?!highlight\z)[A-Za-z][A-Za-z0-9_+-]*\z/]
      pre["class"] = "brush: #{language};" if language
      pre.inner_html = pre.text
    end
  end

  # Flattens leading fragment links in headings while preserving alias anchors.
  #
  # @param fragment [Nokogiri::HTML4::DocumentFragment] HTML fragment.
  #
  # @return [void]
  def normalize_heading_links(fragment)
    document = fragment.document
    fragment.css("h1, h2, h3, h4, h5, h6").each do |heading|
      normalize_heading_link(heading, document)
    end
  end

  # Normalizes one heading's leading fragment link.
  #
  # @param heading [Nokogiri::XML::Element] Heading element.
  # @param document [Nokogiri::HTML4::Document] Owning document.
  #
  # @return [void]
  def normalize_heading_link(heading, document)
    link = heading.xpath("./a[starts-with(@href, '#') and string-length(@href) > 1]").find do |anchor|
      leading_heading_link?(anchor)
    end
    return unless link

    id = link["href"].delete_prefix("#")
    link.replace(link.children)
    return if id == RDoc::Text.to_anchor(heading.text)

    heading.add_child(document.create_element("span", "class" => "legacy-anchor", "id" => id))
  end

  # Checks whether a link is the first visible content in its heading.
  #
  # @param anchor [Nokogiri::XML::Element] Candidate heading link.
  #
  # @return [Boolean] Whether no visible text precedes the link.
  def leading_heading_link?(anchor)
    anchor.text.match?(/\S/) &&
      anchor.xpath("preceding-sibling::node()").none? { |sibling| sibling.text.match?(/\S/) }
  end

  # Replaces legacy anchors with tokens that survive reverse_markdown.
  #
  # @param anchors [Nokogiri::XML::NodeSet] Legacy anchor spans.
  #
  # @return [Array<Array<String>>] Token and anchor ID pairs.
  def tokenize_legacy_anchors(anchors)
    anchors.map.with_index do |span, index|
      token = "RDocMarkdownAnchor#{index}End"
      id = span["id"]
      span.replace(token)
      [token, id]
    end
  end

  # Normalizes links before reverse_markdown converts the fragment.
  #
  # @param fragment [Nokogiri::HTML4::DocumentFragment] HTML fragment.
  #
  # @return [void]
  def normalize_links(fragment)
    document = fragment.document
    fragment.css("a").each { |link| normalize_link(link, document) }
  end

  # Normalizes one HTML link.
  #
  # @param link [Nokogiri::XML::Element] Link element.
  # @param document [Nokogiri::HTML4::Document] Owning document.
  #
  # @return [void]
  def normalize_link(link, document)
    receiver = link.text
    href = link["href"].to_s

    return replace_index_reference(link, document, href) if index_reference?(receiver, href)
    return link["href"] = "https://#{href}" if href.start_with?("www.")
    return if href.match?(/\A(?:https?:\/\/|mailto:|#)/i)

    link["href"] = normalized_link_target(href)
  end

  # Checks whether RDoc encoded an indexing expression as a link.
  #
  # @param receiver [String] Visible receiver text.
  # @param href [String] Link target.
  #
  # @return [Boolean] Whether the link represents Ruby indexing syntax.
  def index_reference?(receiver, href)
    receiver.match?(/\A(?:[A-Z][A-Za-z0-9_]*(?:::[A-Z][A-Za-z0-9_]*)*|[a-z_][A-Za-z0-9_]*)\z/) &&
      href.match?(/\A(?::.+|".+")\z/)
  end

  # Replaces an indexing link with a code element.
  #
  # @param link [Nokogiri::XML::Element] Link element.
  # @param document [Nokogiri::HTML4::Document] Owning document.
  # @param href [String] Encoded index expression.
  #
  # @return [void]
  def replace_index_reference(link, document, href)
    link.replace(document.create_element("code") { |code| code.content = "#{link.text}[#{href}]" })
  end

  # Rewrites an internal RDoc HTML target to its Markdown equivalent.
  #
  # @param href [String] Original link target.
  #
  # @return [String] Normalized target.
  def normalized_link_target(href)
    href.sub(/\.html(?=[?#]|\z)/i, ".md")
      .sub(%r{\A/(?=.+\.md(?:[?#]|\z))}, "")
      .sub(%r{\A((?:\.\./)*)(?:files|classes|modules)/(?=.+\.md(?:[?#]|\z))}, '\1')
  end

  # Converts a normalized fragment with the configured reverse_markdown mode.
  #
  # @param fragment [Nokogiri::HTML4::DocumentFragment] HTML fragment.
  #
  # @return [String] Mutable Markdown output.
  def reverse_markdown(fragment)
    ReverseMarkdown.convert(
      fragment,
      github_flavored: true,
      unknown_tags: markdown_unknown_tags
    ).dup
  end

  # Restores tokenized legacy anchors in converted Markdown.
  #
  # @param markdown [String] Converted Markdown.
  # @param anchor_aliases [Array<Array<String>>] Token and anchor ID pairs.
  #
  # @return [void]
  def restore_anchor_aliases(markdown, anchor_aliases)
    anchor_aliases.each do |token, id|
      markdown.gsub!(token, %(<a id="#{id}"></a>))
    end
  end

  # Builds an HTML anchor tag.
  #
  # @param id [String] Fragment identifier for the generated anchor.
  #
  # @return [String] HTML anchor tag.
  def anchor(id)
    %(<a id="#{id}"></a>)
  end

  # Applies final whitespace and link normalization before writing Markdown.
  #
  # @param content [String] Markdown content.
  # @param current_output_path [String] Output path for the file being written.
  #
  # @return [String] Final Markdown ending with one newline.
  def finalize_markdown(content, current_output_path:)
    normalized = normalize_internal_links(
      content.lines.map(&:rstrip).join("\n"),
      current_output_path: current_output_path
    ).sub(/\n{3,}/, "\n\n").gsub(/^(#+ .+)\n\n/, "\\1\n")
    "#{normalized}\n"
  end

  # Increases Markdown heading levels without exceeding level six.
  #
  # @param markdown [String] Markdown content.
  # @param heading_level_offset [Integer] Heading levels to add.
  #
  # @return [String] Markdown with shifted headings.
  def shift_headings(markdown, heading_level_offset)
    markdown.gsub(/^(#+)(\s)/) do
      hashes = Regexp.last_match(1)
      spaces = Regexp.last_match(2)
      level = [hashes.length + heading_level_offset, 6].min
      "#{"#" * level}#{spaces}"
    end
  end

  # Converts RDoc definition-list code blocks into Markdown lists.
  #
  # @param markdown [String] Markdown content.
  #
  # @return [String] Markdown with convertible blocks normalized.
  def normalize_definition_list_code_blocks(markdown)
    markdown.gsub(/```[^\n]*\n(.+?)\n```/m) do
      body = Regexp.last_match(1)
      converted = convert_definition_list_block(body)
      converted || Regexp.last_match
    end
  end

  # Converts a single definition-list code block.
  #
  # @param body [String] Code block body.
  #
  # @return [String, nil] Converted Markdown, or nil when the block is not a definition list.
  def convert_definition_list_block(body)
    lines = body.lines
    return nil unless lines.all? { |line| definition_list_line?(line) }

    lines.map do |line|
      stripped = line.strip
      next if stripped.empty?
      next "#{stripped.sub(/::\z/, "")}:" if stripped.end_with?("::")

      "- #{stripped.sub(/\A\*\s/, "")}"
    end.join("\n")
  end

  # Checks whether a line can appear in a converted definition list.
  #
  # @param line [String] Markdown line.
  #
  # @return [Boolean] True when the line matches RDoc definition-list output.
  def definition_list_line?(line)
    stripped = line.strip
    stripped.empty? || stripped.end_with?("::") || stripped.match?(/\A\*\s/)
  end

  module_function :normalized_html_fragment,
    :context_anchor?,
    :move_legacy_anchors_into_headings,
    :normalize_pre_blocks,
    :normalize_heading_links,
    :normalize_heading_link,
    :leading_heading_link?,
    :tokenize_legacy_anchors,
    :normalize_links,
    :normalize_link,
    :index_reference?,
    :replace_index_reference,
    :normalized_link_target,
    :restore_anchor_aliases,
    :anchor,
    :shift_headings,
    :normalize_definition_list_code_blocks,
    :convert_definition_list_block,
    :definition_list_line?
end
