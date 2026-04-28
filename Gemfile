# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in rdoc-markdown.gemspec
gemspec

gem "rake", "~> 13.0"

gem "erb_lint", require: false
gem "minitest", "~> 5.0"
gem "standard"

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.3")
  gem "mutant"
  gem "mutant-minitest"
  gem "mutex_m"
end
