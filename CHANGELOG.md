# Changelog

## Unreleased

## 0.8.0

### Added
- Add `markdown_unknown_tags` RDoc option to configure reverse_markdown unknown tag handling

### Changed
- Fail before generation when RDoc supplies a non-string output directory
- Markdown template will only include visible classes/module/methods, same as rdoc does with HTML templates

## 0.7.0

### Changed
- Relax the development Bundler constraint to allow Bundler 4, and refresh the dependency lockfile with the newer toolchain.
- Huge refactoring done to template, powered by mutant testing mostly.

### Added
- SimpleCov test coverage reporting.
- Mutation testing coverage
- StandardRB was added
