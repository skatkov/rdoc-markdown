# frozen_string_literal: true

module ERBLint
  module Linters
    class NoEmbeddedAssets < Linter
      include LinterRegistry

      PATTERNS = [
        [/(?:javascript_tag|javascript_include_tag|javascript_pack_tag|stylesheet_link_tag|stylesheet_pack_tag)\b/i,
          "Avoid Rails JavaScript and stylesheet helpers in markdown ERB templates."],
        [/\bcontent_tag\s*\(?\s*[:"'](?:script|style)\b/i,
          "Avoid helper-generated `<script>` and `<style>` tags in markdown ERB templates."],
        [/\btag\.(?:link|script|style)\b/i,
          "Avoid helper-generated asset tags in markdown ERB templates."]
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
