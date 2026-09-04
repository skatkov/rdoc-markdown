# Changelog

## Unreleased

- Avoid syntax highlighting verbatim HTML that Markdown conversion discards.

## 0.19.1

- Store fullpath for files, instead of just file names.

## 0.19.0

- Remove the `markdown_unknown_tags` option and use reverse_markdown's default handling.
- Preserve source file extensions in search-index names.

## 0.18.0

- Rework heading for the document

## 0.17.2

- Remove spaces after headers
- Remove legacy anchor links
- Remove extra files that are not required (js, css and etc)

## 0.17.1

- Don't include files with .tt extension

## 0.17.0

- Remove fabricated external namespaces and preserve exact class and module identities across generated paths, index entries, metadata, and links.
- Avoid broken alias links when the target method is hidden or its owner page is not generated.
- Preserve localized section bodies, Markdown format, and source location when translating comments.
- Avoid duplicate unresolved cross-reference warnings during class and module selection.

## 0.16.1

- Fix copying Markdown pages when RDoc receives relative input paths.

## 0.16.0

- Don't convert markdown files from source folder. Just copy them.

## 0.15.0

- remove special files types (changelog, readme), just label everything 'File'
- change "Page" file type to just "File"

## 0.14.0

- BREAKING: Removing RDoc 7 compatibility code. Support RDoc 8 only.
- Remove extra spacing between method group headings and  content.
- Reworked documentation cross-linking. Tests will fail, if cross-linked document can't be found.

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
