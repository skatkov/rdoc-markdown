# frozen_string_literal: true

# Normalizes RDoc and RBS method signatures for headings.
module RDoc::Generator::Markdown::Signatures
  # Signature opening delimiters and their matching closers.
  DELIMITER_PAIRS = {
    "(" => ")", "[" => "]", "{" => "}"
  }.freeze

  # Builds a complete method heading signature from RDoc and store metadata.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  # @param store [RDoc::Store] Documentation store with sidecar signatures.
  #
  # @return [String] Complete signature including the method name or documented receiver.
  def self.render_method_signature(method, store)
    name = method.name
    signatures = method.type_signature_lines || store.rbs_signature_for(method)
    if !signatures && ["[]", "[]="].include?(name) && (call_seq = method.call_seq)
      return call_seq.lines.map { |line| normalize_signature(line) }.join(" | ")
    end
    signatures ||= [method.param_seq]

    signatures = signatures.filter_map do |signature|
      next unless signature&.match?(/\S/)

      signature = normalize_signature(signature)
      signature = " #{signature}" if signature.start_with?("->")
      merge_method_signature_arguments(signature, method.params)
    end

    "#{name}#{signatures.empty? ? "()" : signatures.join(" | ")}"
  end

  # Normalizes spacing in a signature without changing its call syntax.
  #
  # @param signature [String] Signature or complete call sequence.
  #
  # @return [String] Signature with consistent arrow and whitespace formatting.
  def self.normalize_signature(signature)
    signature.gsub("->", " -> ").gsub(/\s+/, " ").strip
  end

  # Merges RDoc parameter names into a type-only signature.
  #
  # @param signature [String] Method signature from RDoc call sequence.
  # @param raw_params [String, nil] Method parameter list from RDoc.
  #
  # @return [String] Signature with names added when safe.
  def self.merge_method_signature_arguments(signature, raw_params)
    params = raw_params.to_s.strip
    params = params[1...-1] if params.start_with?("(") && params.end_with?(")")

    signature_args, signature_suffix = split_signature_arguments_and_suffix(signature)
    return signature unless signature_args

    param_parts = split_signature_list(params)
    signature_parts = split_signature_list(signature_args)
    return signature unless param_parts.length.eql?(signature_parts.length)

    merged_signature(param_parts, signature_parts, signature_suffix) || signature
  end

  # Merges matching parameter and type fragments only when names can be inferred.
  # @param param_parts [Array<String>] RDoc parameter fragments.
  # @param signature_parts [Array<String>] Signature type fragments.
  # @param signature_suffix [String] Text following the argument list.
  # @return [String, nil] Merged signature, or nil when merging is unsafe or unnecessary.
  def self.merged_signature(param_parts, signature_parts, signature_suffix)
    param_names = param_parts.map { |part| part[/\A(?:\*\*|\*|&)?([a-z_]\w*):?\z/, 1] }
    return if param_names.any?(&:nil?)
    return if signature_parts.zip(param_names).all? { |part, name| part.match?(/(?<!\w)#{name}(?!\w)/) }

    merged_args = param_parts.zip(signature_parts).map do |param, type|
      separator = param.end_with?(":") ? " " : ": "
      "#{param}#{separator}#{type}"
    end

    "(#{merged_args.join(", ")})#{signature_suffix}"
  end

  # Splits a parenthesized signature into arguments and suffix.
  #
  # @param signature [String] Method signature.
  #
  # @return [Array<String>, nil] Argument text and suffix, or nil when not parenthesized.
  def self.split_signature_arguments_and_suffix(signature)
    return unless signature.start_with?("(")

    depth = 0

    signature.each_char.with_index do |char, index|
      depth += 1 if char == "("

      next unless char == ")"

      depth -= 1
      return [signature[1...index], signature[(index + 1)..]] if depth.zero?
    end
  end

  # Splits a comma-separated signature list while preserving nested groups.
  #
  # @param list [String] Signature argument list.
  #
  # @return [Array<String>] Signature parts.
  def self.split_signature_list(list)
    parts = []
    current = +""
    delimiters = []

    list.each_char do |char|
      if char == "," && delimiters.empty?
        parts << current.strip
        current.clear
      else
        closing = DELIMITER_PAIRS[char]
        if closing
          delimiters << closing
        elsif char == delimiters.last
          delimiters.pop
        end
        current << char
      end
    end

    parts << current.strip unless current.empty?
    parts
  end
end
