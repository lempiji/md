# Contributing

Thanks for contributing to `md`.

This document is executable with `md` and also serves as a small literate task runner for local development.

## Overview

`md` is a D command-line tool that executes Markdown code blocks and is verified in CI against the repository's own docs and examples.

- `README.md` and `README.ja.md` are user-facing executable documents.
- `examples/` contains focused regression samples.
- `scripts/test/` contains shell-based integration checks.
- `CONTRIBUTING.md` is the developer-facing entry point for local build and test commands.

When changing behavior, prefer updating docs and examples together so the executable documentation stays aligned with the implementation.

## Prerequisites

You should have the following available in your environment:

- A D toolchain with `dub`
- `sh` and `bash`
- A writable temp directory

Some environments hit DUB cache permission errors. When that happens, use the `*_tmp` tasks below, which set `HOME=/tmp` before invoking `dub`.

## Development tasks

Use these commands for normal local development:

```
dub run md -- CONTRIBUTING.md --filter build
dub run md -- CONTRIBUTING.md --filter test
dub run md -- CONTRIBUTING.md --filter check
```

`check` is the main "does this still work?" path and runs both build and test tasks in order.

If you see DUB cache permission errors, use the `*_tmp` variant instead.

```
dub run md -- CONTRIBUTING.md --filter build_tmp
dub run md -- CONTRIBUTING.md --filter test_tmp
dub run md -- CONTRIBUTING.md --filter check_tmp
```

## Development workflow

A typical change looks like this:

1. Make the code or documentation change.
2. Run `dub test`.
3. Run the relevant executable docs with `dub run md -- <doc>.md`.
4. Run the shell integration checks if the change affects shell support or logging.

For day-to-day work, `check` or `check_tmp` is the fastest contributor-oriented entry point.

### Literate build and test tasks

```sh name=build name=test name=check
compiler_arg=""
if [ -n "${DC:-}" ]; then
  compiler_arg="--compiler=$DC"
fi
```

```sh name=build name=check
echo "[task] build"
dub build $compiler_arg
```

```sh name=test name=check
echo "[task] test"
dub test $compiler_arg
```

Run `--filter check` to execute both the build and test tasks in order.

### Permission-safe build and test tasks

```sh name=build_tmp name=test_tmp name=check_tmp
export HOME=/tmp
compiler_arg=""
if [ -n "${DC:-}" ]; then
  compiler_arg="--compiler=$DC"
fi
```

```sh name=build_tmp name=check_tmp
echo "[task] build (HOME=/tmp)"
dub build $compiler_arg
```

```sh name=test_tmp name=check_tmp
echo "[task] test (HOME=/tmp)"
dub test $compiler_arg
```

## CI parity

GitHub Actions currently verifies:

- `dub build`
- `dub test`
- `README.md` and `README.ja.md`
- example markdown files under `examples/`
- shell integration tests under `scripts/test/`
- `CONTRIBUTING.md --filter check_tmp`

If you change the CLI, shell execution behavior, log formatting, or executable docs, try to keep local verification close to the CI path.

## Making changes

Please keep the following in mind when preparing a change:

- Update executable docs when user-facing behavior changes.
- Add or extend regression samples in `examples/` when a change needs a concrete reproduction.
- Add or update shell integration tests when changing `sh`/`bash` execution behavior, logging, or error handling.
- Keep README focused on user-facing usage; use this file for contributor-oriented workflows.

## Pull requests

A good pull request usually includes:

- A short explanation of the problem and the intended behavior
- Notes about user-visible changes
- The verification steps you ran locally
- Doc updates when examples, commands, or behavior changed

If a change is release-sensitive, call that out explicitly in the PR description.

## Release-sensitive areas

Be especially careful when touching these areas because they directly affect release confidence:

- `source/commands/main.d`
- `README.md` and `README.ja.md`
- `CONTRIBUTING.md`
- `.github/workflows/test-md.yml`
- `scripts/test/`
