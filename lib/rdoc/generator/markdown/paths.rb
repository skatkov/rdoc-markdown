# frozen_string_literal: true

# Resolves source and generated documentation paths.
module RDoc::Generator::Markdown::Paths
  # Converts a qualified object name into a Markdown path.
  #
  # @param class_name [String] Qualified class or module name.
  #
  # @return [String] Relative Markdown path.
  def turn_to_path(class_name)
    "#{class_name.gsub("::", "/")}.md"
  end

  # Builds the Markdown output path for an RDoc page.
  #
  # @param page [RDoc::TopLevel] Page object to render.
  #
  # @return [String] Relative Markdown path.
  def page_output_path(page)
    relative_name = page.relative_name
    source_path = normalize_input_path_for_output(relative_name)
    return source_path if relative_name.match?(/\.(?:md|markdown)\z/i)

    dirname = File.dirname(source_path)
    basename = "#{File.basename(source_path).tr(".", "_")}.md"

    return basename if dirname == "."

    "#{dirname}/#{basename}"
  end

  # Returns the canonical Markdown path for a class or module.
  #
  # @param code_object [RDoc::Context] Class or module object.
  #
  # @return [String] Relative Markdown path.
  def output_path_for(code_object)
    turn_to_path(code_object.full_name)
  end

  # Rewrites local Markdown links relative to the current output file.
  #
  # @param markdown [String] Markdown content.
  # @param current_output_path [String] Output path for the file being written.
  #
  # @return [String] Markdown with normalized internal links.
  def normalize_internal_links(markdown, current_output_path:)
    RDoc::Generator::Markdown::Paths.rewrite_internal_links(
      markdown,
      current_output_path,
      generation_state
    )
  end

  private :turn_to_path, :page_output_path, :output_path_for, :normalize_internal_links

  # Rewrites links using explicit generated-path state.
  #
  # @param markdown [String] Markdown content.
  # @param current_output_path [String] Output path for the current file.
  # @param state [RDoc::Generator::Markdown::GenerationState] Prepared generation state.
  #
  # @return [String] Markdown with normalized internal links.
  def self.rewrite_internal_links(markdown, current_output_path, state)
    current_dir = Pathname.new(current_output_path).dirname

    markdown.gsub(%r{\]\(([^)]+)\)}) do
      target = Regexp.last_match(1)
      path = target.sub(/[?#].*\z/, "")
      suffix = target[path.length..]

      resolved = resolve_output_path_from(path, current_dir, state)
      rewritten = resolved ? Pathname.new(resolved).relative_path_from(current_dir) : path
      "](#{rewritten}#{suffix})"
    end
  end

  # Resolves a link against explicit generated-path state.
  #
  # @param path [String] Link path from Markdown content.
  # @param current_dir [Pathname] Directory of the current output file.
  # @param state [RDoc::Generator::Markdown::GenerationState] Prepared generation state.
  #
  # @return [String, nil] Resolved output path, or nil when unresolved.
  def self.resolve_output_path_from(path, current_dir, state)
    candidates = [path, path.delete_prefix("#{state.root_path_segment}/")]
    candidates += candidates.map { |candidate| candidate.sub(/_(md|markdown)\.md\z/i, '.\1') }
    expanded_candidates = candidates.map { |candidate| current_dir.join(candidate).cleanpath.to_s }

    (candidates + expanded_candidates).find { |candidate| state.known_output_paths.include?(candidate) }
  end

  # Normalizes an input filename into an output-relative source path.
  #
  # @param path [String] RDoc input path.
  #
  # @return [String] Normalized path without root prefixes.
  def normalize_input_path_for_output(path)
    RDoc::Generator::Markdown::Paths.normalize_input_path(path, source_dir)
  end

  private :normalize_input_path_for_output

  # Normalizes an input path against an explicit source directory.
  #
  # @param path [String] RDoc input path.
  # @param source_dir [String] Absolute documentation source directory.
  #
  # @return [String] Normalized path without root prefixes.
  def self.normalize_input_path(path, source_dir)
    normalized = path.tr("\\", "/").sub(%r{\A\./}, "")
    normalized = normalized.sub(%r{\A#{Regexp.escape(source_dir)}/}, "")
    normalized = normalized.sub(%r{\A/}, "")

    root_basename = File.basename(source_dir)
    normalized.sub(%r{\A#{Regexp.escape(root_basename)}/}, "")
  end
end
