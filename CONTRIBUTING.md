# Contributing to Norse Architecture

Thank you for your interest in contributing. These are the default guidelines for all repositories in the Norse Architecture organization. Individual repositories may extend or override them with their own `CONTRIBUTING.md` — when one exists, it takes precedence.

## Before You Start

- **Open an issue first.** For anything beyond a trivial fix (typos, broken links), open an issue describing the problem or proposal before writing code. Design discussion happens in the issue; pull requests are for implementations that have already been agreed upon.
- **Check existing issues and discussions.** Your idea or bug may already be tracked.
- **One concern per pull request.** Keep changes focused and reviewable.

## Development Workflow

1. Fork the repository and create a branch from `master`.
2. Make your changes, including tests for any behavioral change.
3. Ensure the solution builds cleanly — warnings are treated as errors across the organization, and that is intentional.
4. Ensure all tests pass.
5. Open a pull request that references the issue it resolves.

## Conventions

- **.NET first.** Projects target the latest LTS or current .NET release as documented in each repository.
- **Indentation:** tabs, except in whitespace-sensitive languages (YAML, Python, F#).
- **Naming is a deliberate act.** Names should describe the role, not the mechanism. Expect naming feedback in review — it is not nitpicking here.
- **Fail loudly.** No silent fallbacks. If an operation can fail, it should fail immediately and visibly.
- **Compile-time over runtime.** Prefer source generators and analyzers over reflection where practical.
- **US English spelling** in code, comments, documentation, and commit messages.

## Commit Messages

- Use the imperative mood ("Add validation", not "Added validation").
- The first line should be a concise summary (~72 characters); add detail in the body if the change warrants it.
- Reference related issues (`Fixes #123`) where applicable.

## Licensing

By contributing, you agree that your contributions will be licensed under the same license as the repository you are contributing to.

## Questions?

See [SUPPORT.md](SUPPORT.md) for where to ask. Thanks for helping build the realms.
