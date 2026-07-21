# Changelog

## Unreleased

- Require Ruby 3.3 and RDoc 8 or newer, removing RDoc 7 compatibility code.
- Remove extra spacing between method group headings and their content.
- reworked documentation cross-linking, moving a lot of logic to converters

## 0.13.2

- Don't add emtpy line break instead of missing metadata

## 0.13.1

- reduce metadata escape characters only to absolutely necessary (|, \)

## 0.13.0

- Adding metadata to classes/modules
- Fixed: cross-linking between markdown files

## 0.12.1

- simplification: automatic root-page inclusion hook.
- Explicit RDoc file lists are authoritative again; unlisted README, CHANGELOG, and similar files are not silently added.

## 0.12.0

- Indexing: Classifies root-level README and GUIDE pages as Readme.
- Indexing: Classifies root-level CHANGELOG and HISTORY pages as Changelog.
- Recognizes .rdoc, .md, and .markdown, case-insensitively by basename.

## 0.11.1

- Changed headings from standalone anchors to adjacent inline anchors:

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
