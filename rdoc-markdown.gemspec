# frozen_string_literal: true

require_relative "lib/rdoc/markdown/version"

Gem::Specification.new do |spec|
  spec.name = "rdoc-markdown"
  spec.version = Rdoc::Markdown::VERSION
  spec.authors = ["Stanislav (Stas) Katkov"]
  spec.email = ["github@skatkov.com"]

  spec.summary = "rdoc generator that produces markdown files"
  spec.description = "rdoc generator that produces markdown files"
  spec.homepage = "https://poshtui.com"
  spec.required_ruby_version = ">= 2.6.0"

  #spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/skatkov/rdoc-markdown"
  spec.metadata["changelog_uri"] = "https://github.com/skatkov/rdoc-markdown"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "rdoc", "~> 6.0"
  spec.add_dependency "erb"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "rdiscount"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
