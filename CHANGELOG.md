# Changelog

## Unreleased

- Merge `:args:` names into rendered method signatures so generated markdown shows `fly(direction: string, velocity: number) -> bool` instead of dropping the argument names from issue #37.
- Relax the development Bundler constraint to allow Bundler 4, and refresh the dependency lockfile with the newer toolchain.
