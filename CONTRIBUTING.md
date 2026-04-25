# Contributing to Flare

Thanks for contributing.

## Getting Started

This package uses:

- `luu` for local tasks
- `rokit` for installing pinned tools
- `lute` for linting and tests
- `selene` for static linting
- `stylua` for formatting

Install the local tools and package dependencies:

```sh
luu install
```

## Common Tasks

Run the full local check suite:

```sh
luu run ci
```

Run individual tasks:

```sh
luu lint
luu test
luu run format
luu run format:check
luu run lint:lute
```

## Contribution Guidelines

- Keep the API Luau-first and straightforward to use.
- Prefer small examples that show the package directly.
- Add or update tests for behavior changes.
- Format code with `stylua`.
- Make sure both `selene` and `lute lint` pass before opening a PR.

## Releases

Loom resolves this package by GitHub tag.

- Create releases with tags in the form `vX.Y.Z`
- Use the same tag value in downstream `rev`
- The release workflow updates `loom.config.luau` on the default branch and refreshes the GitHub release notes
