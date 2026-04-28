# frozen_string_literal: true

module ERBLint
  module Linters
    class NoEmbeddedAssets < Linter
      include LinterRegistry

      PATTERNS = [
        [/<\s*script\b/i, "Avoid raw `<script>` tags in markdown ERB templates."],
        [/<\s*style\b/i, "Avoid raw `<style>` tags in markdown ERB templates."],
        [/<\s*link\b[^>]*\brel\s*=\s*(?:\"[^\"]*\bstylesheet\b[^\"]*\"|'[^']*\bstylesheet\b[^']*'|[^\s>]*stylesheet[^\s>]*)/i,
          "Avoid stylesheet `<link>` tags in markdown ERB templates."],
        [/\sstyle\s*=/i, "Avoid inline `style` attributes in markdown ERB templates."],
        [/(?:javascript_tag|javascript_include_tag|javascript_pack_tag|stylesheet_link_tag|stylesheet_pack_tag)\b/i,
          "Avoid Rails JavaScript and stylesheet helpers in markdown ERB templates."]
      ].freeze

      def run(processed_source)
        content = processed_source.file_content

        PATTERNS.each do |pattern, message|
          content.scan(pattern) do
            match = Regexp.last_match
            add_offense(processed_source.to_source_range(match.begin(0)...match.end(0)), message)
          end
        end
      end
    end
  end
end
