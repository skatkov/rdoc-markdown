# frozen_string_literal: true

class RDoc::Generator::Markdown
  # Native reference policy, independent of HTML rendering and output buffers.
  module References
    # Options attached to the RDoc context being documented.
    # @return [RDoc::Options] Current options.
    def options
      rendering.context.options
    end

    # Resolves automatic references outside explicit link labels.
    # @param name [String] Reference candidate.
    # @return [String] Linked or literal Markdown.
    def handle_regexp_CROSSREF(name)
      text = convert_string(name)
      return text if in_link_label? || options.autolink_excluded_words&.include?(name)
      return text if name.match?(/@[\w-]+\.[\w-]/)

      reference_link(name) || ((name.include?("#") && !name.start_with?("#")) ? Syntax.code(name) : text)
    end

    # Formats automatic URLs without linking URLs inside link labels.
    # @param url [String] URL candidate.
    # @return [String] Linked or literal Markdown.
    def handle_regexp_HYPERLINK(url)
      return convert_string(url) if in_link_label?

      label = convert_string(url.sub(%r{\A(?:link|https?|mailto|ftp|irc):/*}, ""))
      gen_url(url, label)
    end

    # Resolves explicit rdoc-ref schemes; other schemes use ToMarkdown.
    # @param url [String] RDoc URL.
    # @return [String] Native Markdown.
    def handle_regexp_RDOCLINK(url)
      return super unless url.start_with?("rdoc-ref:")

      name = url.delete_prefix("rdoc-ref:")
      in_link_label? ? convert_string(name) : explicit_reference(name)
    end

    # Reports missing explicit references and retains their visible labels.
    # @param name [String] Reference name.
    # @param label [String, nil] Optional native label.
    # @return [String] Reference or visible fallback.
    def explicit_reference(name, label = nil)
      found = reference_link(name, label: label)
      return found if found

      text = label || convert_string(name)
      puts "#{rendering.context.path}: `rdoc-ref:#{name}` can't be resolved for `#{text}`" if options.warn_missing_rdoc_ref
      text
    end

    # Resolves a reference only when its owning page is emitted.
    # @param name [String] Reference name.
    # @param label [String, nil] Optional native label.
    # @return [String, nil] Native link, unlinked code, or an unresolved reference.
    def reference_link(name, label: nil)
      target_name, section = split_reference(name)
      local = target_name.empty?
      ref = rendering.reference.resolve(target_name)
      return if !ref && !(local && section)

      text = reference_text(name, label, ref)
      return text if ref && !emitted_reference?(ref)

      path = ref ? ref.as_href(rendering.context.path) : ""
      path = reference_section(path, ref, section) if section
      Syntax.link(text, path)
    end

    private

    # Main keeps file references inside code spans literal, not prose links.
    # @param text [String] Inline code candidate.
    # @return [String, nil] Code-formatted object link or literal-code fallback.
    def code_reference(text)
      return if in_link_label?

      name = text.delete_prefix("\\")
      return unless code_reference_syntax?(name)

      target_name, = split_reference(name)
      return if RDoc::TopLevel === rendering.reference.resolve(target_name)

      linked = reference_link(name)
      text.start_with?("\\") ? (Syntax.code(name) if linked) : linked
    end

    # Separates inline-code display policy from target resolution.
    # @param name [String] Reference name.
    # @param label [String, nil] Explicit native label.
    # @param ref [RDoc::CodeObject, nil] Resolved target.
    # @return [String] Native inline Markdown.
    def reference_text(name, label, ref)
      display = options.show_hash ? name : name.delete_prefix("#")
      target, section = split_reference(display)
      if section
        return label if label

        title = convert_string(RDoc::Text.decode_legacy_label(section))
        return target.empty? ? title : "#{title} at #{Syntax.code(target)}"
      end

      plain = label ? label.delete("\\") : display
      text = label || convert_string(display)
      (!(RDoc::TopLevel === ref) && (!label || plain == name)) ? Syntax.code(plain) : text
    end

    # Matches both explicit method hashes and hyperlink-all method notation.
    # @param name [String] Complete inline code text without suppression.
    # @return [Boolean] Whether a reference starts the span and consumes its words.
    def code_reference_syntax?(name)
      patterns = [RDoc::CrossReference::CROSSREF_REGEXP]
      patterns << RDoc::CrossReference::ALL_CROSSREF_REGEXP if options.hyperlink_all
      patterns.any? do |pattern|
        match = pattern.match(name)
        match&.begin(1) == 0 && match.post_match.match?(/\A[[:punct:]\s]*\z/)
      end
    end

    # Separates heading labels without mistaking unary operator method names.
    # @param name [String] Reference name.
    # @return [String, Array(String, String, nil)] Target and optional heading label.
    def split_reference(name)
      return name if name.end_with?("+@", "-@")

      target, separator, section = name.partition("@")
      [target, (section unless separator.empty?)]
    end

    # Tests the owning page rather than the individual member's identity.
    # @param ref [RDoc::CodeObject] Resolved target.
    # @return [Boolean] Whether that target has a generated page.
    def emitted_reference?(ref)
      owner = ref
      owner = owner.parent until RDoc::ClassModule === owner || RDoc::TopLevel === owner
      rendering.output_ids.include?(owner.object_id)
    end

    # Applies RDoc's canonical method, named-section, and page heading anchors.
    # @param path [String] Relative RDoc target.
    # @param ref [RDoc::CodeObject, nil] Target or a local heading reference.
    # @param section [String] Encoded heading label.
    # @return [String] Anchored target.
    def reference_section(path, ref, section)
      decoded = RDoc::Text.decode_legacy_label(section)
      slug = RDoc::Text.to_anchor(decoded)
      return "#{path}-#{slug}" if path.include?("#")

      named = ref.sections.find { |candidate| candidate.title == decoded } if ref
      anchor = if named
        named.aref
      elsif RDoc::ClassModule === ref
        "#{ref.aref}-#{slug}"
      else
        slug
      end
      "#{path}##{anchor}"
    end
  end
end
