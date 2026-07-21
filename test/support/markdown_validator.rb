# frozen_string_literal: true

require "cgi"
require "commonmarker"

class MarkdownValidator
  ValidationError = Class.new(StandardError)

  def initialize(root_dir)
    @root_dir = File.expand_path(root_dir)
    @anchors_cache = {}
  end

  def validate!
    files = Dir[File.join(@root_dir, "**/*.md")].sort
    raise ValidationError, "No markdown files found in #{@root_dir}" if files.empty?

    files.each { |file| validate_file(file) }
    files.size
  end

  private

  def validate_file(file)
    content = File.read(file)

    document = parse_gfm!(content, file)

    document.walk do |node|
      next unless node.type == :link

      target = node.url
      raise ValidationError, "empty anchor link found in #{relative_path(file)}" if target == "#" && node.first_child.nil?
      next if target.match?(%r{\A(?:https?://|mailto:|#)})

      raise ValidationError, "local .html link found in #{relative_path(file)}" if target.sub(/[?#].*\z/, "").end_with?(".html")
      validate_local_link!(file, target)
    end
  end

  def validate_local_link!(source_file, target)
    base_target = target.sub(/[?#].*\z/, "")
    fragment = target[/#(.+)\z/, 1]

    target_file = if base_target.empty?
      source_file
    else
      File.expand_path(CGI.unescape(base_target), File.dirname(source_file))
    end

    unless within_root?(target_file) && File.file?(target_file)
      raise ValidationError,
        "broken local link in #{relative_path(source_file)} -> #{target.inspect}"
    end

    return if fragment.nil? || fragment.empty?

    anchor = CGI.unescape(fragment)
    anchors = anchors_for(target_file)
    return if anchors.include?(anchor)

    raise ValidationError,
      "missing anchor ##{anchor} in #{relative_path(target_file)} (from #{relative_path(source_file)})"
  end

  def anchors_for(file)
    @anchors_cache[file] ||= begin
      content = File.read(file)
      anchors = Set.new(content.scan(/<a\s+id="([^"]+)"/).flatten)
      headings = Hash.new(0)

      content.each_line do |line|
        match = line.match(/^\s{0,3}#+\s+(.+?)\s*$/)
        next unless match

        heading = match[1].sub(/\s+#+\s*\z/, "")
        slug = github_slug(heading)
        next if slug.empty?

        index = headings[slug]
        headings[slug] += 1

        anchors << (index.zero? ? slug : "#{slug}-#{index}")
      end

      anchors
    end
  end

  def github_slug(heading)
    text = heading.dup
    text.gsub!(/`([^`]*)`/, '\\1')
    text.gsub!(/\[([^\]]+)\]\([^)]+\)/, '\\1')
    text.gsub!(/<[^>]+>/, "")
    text = CGI.unescapeHTML(text)
    text.downcase!
    text.gsub!(/[^\p{Alnum}\- _]/u, "")
    text.tr!(" ", "-")
    text.squeeze!("-")
    text.gsub!(/\A-+|-+\z/, "")
    text
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
