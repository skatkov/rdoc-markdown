# Changelog

## Unreleased

## 0.11.0

### Changed
- properly convert code block to markdown with language definition

### Fixed
- Put generated anchors before heading lines so terminal markdown renderers parse headings correctly.

## 0.10.3
- Remove extra spacing between title 3 and content

## 0.10.2

### Fixed
- Generated anchors stay inline with headings

## 0.10.1

### Changed
- Stop adding a global "Type signatures available" notice to generated class/module pages.

## 0.10.0

- Reworked RDoc 8 support

## 0.9.0

### Fixed
- Render RDoc 8 inline and sidecar RBS signatures in Markdown method headings.
- Resolve explicit relative `.rbs` inputs against the directory where RDoc started, not the output directory.

### Changed
- Run CI against both RDoc 7 and RDoc 8 dependency sets.

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
