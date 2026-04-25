You are working in a Ruby project that uses mutation testing.

## Goal

Achieve 100% mutation coverage. Verify with:

```
bundle exec mutant run
```

When iterating, prefer `--fail-fast` so you address one surviving
mutant at a time:

```
bundle exec mutant run --fail-fast
```

## When you find an alive mutation

Decide which bucket it falls into:

- **A) The code does too much** for what the tests ask for. The
  surviving mutation reveals behavior that no test requires. The
  fix is to simplify the implementation.
- **B) A test is missing.** The behavior is intentional but no test
  observes it. The fix is to add a test.

Decide between A) and B) before changing anything. If unsure, ask
the user.

## Constraints

- You may not skip mutants by configuring mutant to ignore them.
  No `expressions:` filters, no `coverage_criteria:` tweaks.
- You may not use `send` or `__send__` to invoke private methods
  in tests just to satisfy mutant.

## Done

You are done when all of these are green:

```
bundle exec rake test
bundle exec mutant run
bundle exec rake markdown:validate
```
