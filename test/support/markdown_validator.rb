# frozen_string_literal: true

require "commonmarker"
require "csv"
require "nokogiri"
# standard:disable Lint/RedundantRequireStatement
require "pathname"
require "set"
# standard:enable Lint/RedundantRequireStatement
require "uri"

class MarkdownValidator
  ValidationError = Class.new(StandardError)

  def initialize(root_dir)
    @root_dir = File.expand_path(root_dir)
    @html_cache = {}
    @anchors_cache = {}
    @sections_cache = {}
  end

  def validate!
    files = Dir[File.join(@root_dir, "**/*.{md,markdown}")].sort
    raise ValidationError, "No markdown files found in #{@root_dir}" if files.empty?

    files.each { |file| validate_file(file) }
    Dir[File.join(@root_dir, "**/index.csv")].sort.each { |file| validate_index!(file) }
    files.size
  end

  private

  def validate_file(file)
    # Validate source links, not Commonmarker's synthetic heading self-links:
    # punctuation-only headings such as `[](*)` produce an empty automatic slug.
    html_for(file, header_ids: nil).css("a[href]").each do |link|
      target = link["href"]
      raise ValidationError, "empty anchor link found in #{relative_path(file)}" if target == "#" && link.children.empty?
      next if target.match?(%r{\A(?:https?://|mailto:)}i)

      raise ValidationError, "local .html link found in #{relative_path(file)}" if target.sub(/[?#].*\z/, "").end_with?(".html")
      validate_local_link!(file, target)
    end
  end

  def validate_index!(file)
    CSV.foreach(file, headers: true).with_index(2) do |row, number|
      target = row["path"]
      raise ValidationError, "missing path in #{relative_path(file)} at row #{number}" if target.nil? || target.empty?

      validate_local_link!(file, target, section: true)
    end
  rescue CSV::MalformedCSVError => e
    raise ValidationError, "invalid #{relative_path(file)}: #{e.message}"
  end

  def validate_local_link!(source_file, target, section: false)
    base_target = target.sub(/[?#].*\z/, "")
    fragment = target[/#(.+)\z/, 1]

    target_file = if base_target.empty?
      source_file
    else
      File.expand_path(URI::DEFAULT_PARSER.unescape(base_target), File.dirname(source_file))
    end

    unless within_root?(target_file) && File.file?(target_file)
      raise ValidationError,
        "broken local link in #{relative_path(source_file)} -> #{target.inspect}"
    end

    return if fragment.nil? || fragment.empty?

    anchor = URI::DEFAULT_PARSER.unescape(fragment)
    section ||= anchor.match?(/\A(?:method|attribute)-[ic]-/)
    anchors = section ? sections_for(target_file) : anchors_for(target_file)
    return if anchors.include?(anchor)

    kind = section ? "heading section" : "anchor"
    raise ValidationError,
      "missing #{kind} ##{anchor} in #{relative_path(target_file)} (from #{relative_path(source_file)})"
  end

  def anchors_for(file)
    @anchors_cache[file] ||= html_for(file).css("[id]").map { |node| node["id"] }.to_set
  end

  def sections_for(file)
    # Only Markdown headings receive source positions from CommonMarker. Raw
    # HTML anchors (including swallowed method headings) are not read sections.
    @sections_cache[file] ||= html_for(file)
      .css("h1[data-sourcepos], h2[data-sourcepos], h3[data-sourcepos], h4[data-sourcepos], h5[data-sourcepos], h6[data-sourcepos]")
      .css("[id]").map { |node| node["id"] }.to_set
  end

  def html_for(file, header_ids: "")
    @html_cache[[file, header_ids]] ||= begin
      document = parse_gfm!(File.read(file), file)
      Nokogiri::HTML.fragment(document.to_html(options: {extension: {header_ids: header_ids}, render: {unsafe: true, sourcepos: true}}))
    end
  end

  def parse_gfm!(content, file)
    Commonmarker.parse(content)
  rescue => e
    raise ValidationError, "GFM render failed for #{relative_path(file)}: #{e.message}"
  end

  def within_root?(path)
    expanded = File.expand_path(path)
    expanded == @root_dir || expanded.start_with?("#{@root_dir}/")
  end

  def relative_path(path)
    Pathname.new(path).relative_path_from(Pathname.new(@root_dir)).to_s
  rescue
    path
  end
end
