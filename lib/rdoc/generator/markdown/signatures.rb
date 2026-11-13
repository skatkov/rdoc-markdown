# frozen_string_literal: true

require "prism"

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
    type_signatures = method.type_signature_lines || store.rbs_signature_for(method)
    if !type_signatures && ["[]", "[]="].include?(name) && (call_seq = method.call_seq)
      return call_seq.lines.map { |line| normalize_signature(line) }.join(" | ")
    end
    params = method.params

    signatures = (type_signatures || [method.param_seq]).filter_map do |signature|
      next unless signature&.match?(/\S/)

      signature = merge_method_signature_arguments(signature, params)
      type_signatures ? signature : restore_method_parameter_defaults(signature, params)
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

  # Restores source defaults for bare argument names in an untyped call sequence.
  #
  # @param signature [String] Normalized call sequence without the method name.
  # @param raw_params [String, nil] Method parameter list from RDoc.
  # @return [String] Signature with matching source default expressions preserved.
  def self.restore_method_parameter_defaults(signature, raw_params)
    signature_args, signature_suffix = split_signature_arguments_and_suffix(signature)
    source_params = ruby_parameters(raw_params)
    documented_params = ruby_parameters(signature_args)
    return signature unless source_params && documented_params

    defaults = source_params.optionals.to_h { |param| [param.name.to_s, param.slice] }
    signature_parts = documented_params.compact_child_nodes.map(&:slice)
    default_parts = signature_parts.map { |part| defaults.fetch(part, part) }
    return signature if default_parts == signature_parts

    "(#{default_parts.join(", ")})#{signature_suffix}"
  end

  # Parses Ruby parameter boundaries without evaluating or rewriting default expressions.
  #
  # @param params [String, nil] Parenthesized or bare Ruby parameters.
  # @return [Prism::ParametersNode, nil] Parameters, or nil for empty or invalid syntax.
  def self.ruby_parameters(params)
    result = Prism.parse("def _ #{params.to_s.lstrip}\nend")
    result.value.statements.body.first.parameters if result.success?
  end

  # Normalizes a signature and merges RDoc parameter names into type-only arguments.
  #
  # @param signature [String] Method signature from RDoc call sequence.
  # @param raw_params [String, nil] Method parameter list from RDoc.
  #
  # @return [String] Signature with names added when safe.
  def self.merge_method_signature_arguments(signature, raw_params)
    signature = normalize_signature(signature)
    signature = " #{signature}" if signature.start_with?("->")
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
    start = 0
    delimiters = []

    list.each_char.with_index do |char, index|
      if char == "," && delimiters.empty?
        parts << list[start...index].strip
        start = index + 1
      end
      closing = DELIMITER_PAIRS[char]
      delimiters << closing if closing
      delimiters.pop if char == delimiters.last
    end

    parts << list[start..].strip if start < list.length
    parts
  end
end
