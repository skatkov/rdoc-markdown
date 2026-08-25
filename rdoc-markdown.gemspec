# frozen_string_literal: true

require_relative "lib/rdoc/markdown/version"

Gem::Specification.new do |spec|
  spec.name = "rdoc-markdown"
  spec.version = Rdoc::Markdown::VERSION
  spec.authors = ["Stanislav (Stas) Katkov"]
  spec.email = ["github@skatkov.com"]
  spec.license = "GPL-3.0-or-later"

  spec.summary = "RDoc plugin to generate markdown documentation  "
  spec.description = "RDoc plugin to generate markdown documentation and search index as sqlite database for entire content."
  spec.homepage = "https://poshtui.com"
  spec.required_ruby_version = ">= 3.3.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/skatkov/rdoc-markdown"
  spec.metadata["changelog_uri"] = "https://github.com/skatkov/rdoc-markdown"

  spec.files = Dir["lib/**/*.{rb,erb}", "sig/**/*.rbs", "{CHANGELOG.md,LICENSE,README.md}"]
  spec.require_paths = ["lib"]

  spec.add_dependency "csv"
  spec.add_dependency "erb"
  spec.add_dependency "rdoc", ">= 8.0"
  spec.add_dependency "reverse_markdown"

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "commonmarker"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-strict", "~> 1.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "ruby-lsp"
end
