# Ginnungagap

> The primordial void from which all realms emerged. GitHub enforces the repository name `.github`; the lore name is Ginnungagap.

This repository contains the organization profile and default community health files for Norse Architecture — the things that exist before and beneath every realm.

## What lives here

- `profile/README.md` — the organization profile shown at [github.com/NorseArchitecture](https://github.com/NorseArchitecture)
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — default contribution guidelines
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) — community standards
- [`SECURITY.md`](SECURITY.md) — how to report vulnerabilities
- [`SUPPORT.md`](SUPPORT.md) — where to get help

These files apply as defaults to every repository in the organization that does not provide its own.

## Shared GitHub Actions

Three reusable workflows live here and are consumed across every realm:

| Workflow | Purpose |
|----------|---------|
| [`ci-build-test.yml`](.github/workflows/ci-build-test.yml) | Restore → build → test → generate Cobertura coverage → post PR comment → enforce branch-coverage threshold |
| [`release-nuget.yml`](.github/workflows/release-nuget.yml) | Runs `ci-build-test` + CodeQL in parallel, then packs, generates an SBOM, pushes to GitHub Packages, and creates a GitHub Release |
| [`update-bifrost.yml`](.github/workflows/update-bifrost.yml) | Stamps the calling realm's new SHA into Bifrost's submodule pointer and pushes; requires the `bifrost_token` secret |

Call them from any realm workflow with:

```yaml
jobs:
  ci:
    uses: NorseArchitecture/.github/.github/workflows/ci-build-test.yml@master
    with:
      minimum_coverage: 80   # optional; org floor is 60%

  release:
    uses: NorseArchitecture/.github/.github/workflows/release-nuget.yml@master

  bifrost:
    uses: NorseArchitecture/.github/.github/workflows/update-bifrost.yml@master
    secrets:
      bifrost_token: ${{ secrets.BIFROST_TOKEN }}
```
