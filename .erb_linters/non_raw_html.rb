# frozen_string_literal: true

module ERBLint
  module Linters
    class NonRawHtml < Linter
      include LinterRegistry

      HTML_PATTERN = /<!--.*?-->|<!DOCTYPE\b[^>]*>|<\/?[A-Za-z][A-Za-z0-9-]*(?=[\s>\/])[^<>]*\/?>/im

      def run(processed_source)
        content = processed_source.file_content
        reported_lines = {}

        content.scan(HTML_PATTERN) do
          match = Regexp.last_match
          source_range = processed_source.to_source_range(match.begin(0)...match.end(0))
          line = source_range.line_range.first
          next if reported_lines[line]

          reported_lines[line] = true
          add_offense(
            source_range,
            "Avoid raw HTML in markdown ERB templates. Generate markdown instead."
          )
        end
      end
    end
  end
end
