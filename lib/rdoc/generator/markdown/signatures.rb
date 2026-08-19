# frozen_string_literal: true

# Normalizes RDoc and RBS method signatures for headings.
module RDoc::Generator::Markdown::Signatures
  # Signature opening delimiters and their matching closers.
  DELIMITER_PAIRS = {
    "(" => ")", "[" => "]", "{" => "}"
  }.freeze

  # Builds the visible method signature used in headings.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  #
  # @return [String] Normalized method signature.
  def method_signature(method)
    RDoc::Generator::Markdown::Signatures.render_method_signature(method, store)
  end

  private :method_signature

  # Builds a method signature from RDoc and store metadata.
  #
  # @param method [RDoc::AnyMethod] Method object to render.
  # @param store [RDoc::Store] Documentation store with sidecar signatures.
  #
  # @return [String] Normalized method signature.
  def self.render_method_signature(method, store)
    signatures = method.type_signature_lines || store.rbs_signature_for(method) || [method.param_seq]

    signatures = signatures.filter_map do |signature|
      next unless signature&.match?(/\S/)

      signature = signature.gsub("->", " -> ")
      signature = signature.gsub(/\s+/, " ").strip
      signature = " #{signature}" if signature.start_with?("->")
      merge_method_signature_arguments(signature, method.params)
    end

    return "()" if signatures.empty?

    signatures.join(" | ")
  end

  # Merges RDoc parameter names into a type-only signature.
  #
  # @param signature [String] Method signature from RDoc call sequence.
  # @param raw_params [String, nil] Method parameter list from RDoc.
  #
  # @return [String] Signature with names added when safe.
  def self.merge_method_signature_arguments(signature, raw_params)
    params = normalized_method_params(raw_params)

    signature_args, signature_suffix = split_signature_arguments_and_suffix(signature)
    return signature unless signature_args

    param_parts = split_signature_list(params)
    signature_parts = split_signature_list(signature_args)
    return signature unless param_parts.length.eql?(signature_parts.length)

    merged = merged_signature(param_parts, signature_parts, signature_suffix)
    merged || signature
  end

  # Merges matching parameter and signature fragments.
  #
  # @param param_parts [Array<String>] RDoc parameter fragments.
  # @param signature_parts [Array<String>] Signature type fragments.
  # @param signature_suffix [String] Text following the argument list.
  #
  # @return [String, nil] Merged signature, or nil when merging is unsafe or unnecessary.
  def self.merged_signature(param_parts, signature_parts, signature_suffix)
    param_names = param_parts.map { |part| extract_parameter_name(part) }
    return if param_names.any?(&:nil?)
    return if signature_parts.zip(param_names).all? { |part, name| signature_part_mentions_name?(part, name) }

    merged_args = param_parts.zip(signature_parts).map do |param, type|
      separator = param.end_with?(":") ? " " : ": "
      "#{param}#{separator}#{type}"
    end

    "(#{merged_args.join(", ")})#{signature_suffix}"
  end

  # Normalizes RDoc's raw parameter string.
  #
  # @param raw_params [String, nil] Parameter list from RDoc.
  #
  # @return [String] Parameter list without outer parentheses.
  def self.normalized_method_params(raw_params)
    params = raw_params.to_s.strip
    params = params[1...-1] if params.start_with?("(") && params.end_with?(")")

    params
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
      if top_level_signature_separator?(char, delimiters)
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

  # Checks whether a character separates top-level signature parts.
  #
  # @param char [String] Current signature character.
  # @param delimiters [Array<String>] Expected closing delimiters.
  #
  # @return [Boolean] Whether the character is a top-level comma.
  def self.top_level_signature_separator?(char, delimiters)
    char == "," && delimiters.empty?
  end

  # Extracts a bare Ruby parameter name from a parameter fragment.
  #
  # @param parameter [String] Parameter fragment.
  #
  # @return [String, nil] Parameter name, or nil when invalid.
  def self.extract_parameter_name(parameter)
    match = parameter.match(/\A(?:\*\*|\*|&)?([a-z_]\w*):?\z/)
    match && match[1]
  end

  # Checks whether a signature fragment already includes a parameter name.
  #
  # @param text [String] Signature fragment.
  # @param name [String] Parameter name.
  #
  # @return [Boolean] True when the name appears as a standalone word.
  def self.signature_part_mentions_name?(text, name)
    text.match?(/(?<!\w)#{name}(?!\w)/)
  end
end
