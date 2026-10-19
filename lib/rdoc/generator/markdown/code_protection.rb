# frozen_string_literal: true

# Keeps literal code out of Markdown heading, link, and whitespace rewrites.
class RDoc::Generator::Markdown::CodeProtection
  # Fences end at a matching or longer delimiter, or at the end of the document.
  # Code spans require matching backtick runs; backslashes only escape openers.
  CODE = %r{
    ^[ ]{0,3}(?<backticks>`{3,})[^`\n]*(?:\n|\z)
    .*?(?:^[ ]{0,3}\k<backticks>`*[\t ]*(?=\n|\z)|\z)
    |
    ^[ ]{0,3}(?<tildes>~{3,})(?!~)[^\n]*(?:\n|\z)
    .*?(?:^[ ]{0,3}\k<tildes>~*[\t ]*(?=\n|\z)|\z)
    |
    (?<![\\`])(?:\\\\)*\K(?<ticks>`+)(?!`)
    .*?(?<!`)\k<ticks>(?!`)
  }mx

  # Runs a prose normalization with code replaced by collision-free tokens.
  #
  # @param markdown [String] Generated Markdown.
  # @yieldparam prose [String] Markdown with code hidden from text rewrites.
  # @yieldreturn [String] Normalized prose with tokens left intact.
  # @return [String] Normalized Markdown with the original code restored.
  def self.rewrite(markdown)
    prefix = +""
    prefix << "_" while markdown.include?(prefix)
    code = {}
    prose = markdown.gsub(CODE) do |literal|
      token = "#{prefix}#{code.length}End"
      code[token] = literal
      token
    end

    yield(prose).gsub(Regexp.union(code.keys), code)
  end
end
