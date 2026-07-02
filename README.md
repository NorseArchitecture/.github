# Ginnungagap

> The primordial void from which all realms emerged. GitHub enforces the repository name `.github`; the lore name is Ginnungagap.

![Ginnungagap — the primordial void before all creation, where the ice of Niflheim and the fire of Muspelheim met and breathed the nine realms into being](https://github.com/user-attachments/assets/aad75315-256a-4103-815c-7534b5b0c22d "Ginnungagap — the void before creation, the source of all realms")

*Image credit: [@norsemythologyclips](https://www.instagram.com/norsemythologyclips/) — go follow them.*

This repository is the substrate beneath every realm in Norse Architecture — the org profile, community health defaults, canonical platform config, reusable workflows, and the automation that carves laws and scatters runes across the org.

## What lives here

- `profile/README.md` — the organization profile at [github.com/NorseArchitecture](https://github.com/NorseArchitecture)
- [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md), [`SUPPORT.md`](SUPPORT.md) — community health defaults applied to every realm that doesn't provide its own
- `config/` — canonical platform config files fanned out to every realm by the scatter system; `manifest.psd1` declares which files each realm receives
- `scripts/` — PowerShell automation: [`carve-the-laws.ps1`](scripts/carve-the-laws.ps1) enforces branch rulesets org-wide, [`scatter-the-runes.ps1`](scripts/scatter-the-runes.ps1) distributes config, [`sound-gjallarhorn.ps1`](scripts/sound-gjallarhorn.ps1) bumps CPM versions in Yggdrasil after each realm release
- `.github/workflows/` — six reusable workflows consumed across every realm

## Carve the laws

`scripts/carve-the-laws.ps1` applies the "Law of the Æsir" branch ruleset to every realm via the GitHub API. Idempotent — PUT if a same-named ruleset exists, POST otherwise:

```powershell
pwsh scripts/carve-the-laws.ps1                                    # all realms
pwsh scripts/carve-the-laws.ps1 Asgard                             # one realm
pwsh scripts/carve-the-laws.ps1 -Repos Asgard,Svartalfheim,Midgard  # selected realms
```

Requires `gh` authenticated with admin on the target repos. Verify a change with:

```bash
gh ruleset list -R NorseArchitecture/<realm>
```

## Config scatter

`config/` is the single source of truth for platform-wide config — `.editorconfig`, `.gitattributes`, `.gitignore`, `global.json`, `nuget.config`, `LICENSE`, MSBuild props, and CI workflows. `config/manifest.psd1` assigns each realm one or more named file groups.

Any push to `config/**` on `master` triggers `scatter-the-runes.yml`, which runs `scatter-the-runes.ps1`. The script clones each realm, copies its assigned files, and opens an auto-merge PR — or pushes onto an existing sync branch if one is already open. Idempotent and safe to re-run manually:

```powershell
pwsh scripts/scatter-the-runes.ps1                                    # all realms
pwsh scripts/scatter-the-runes.ps1 Svartalfheim                       # one realm
pwsh scripts/scatter-the-runes.ps1 -Realms Asgard,Svartalfheim,Midgard  # selected realms
pwsh scripts/scatter-the-runes.ps1 -DryRun                            # print plan, no writes
```

Requires `SCATTER_PAT` — a PAT with `repo` scope set as an org secret. Locally: `gh auth login` or `$env:GH_TOKEN`.

## Reusable workflows

| Workflow | Purpose |
|----------|---------|
| [`ci-build-test.yml`](.github/workflows/ci-build-test.yml) | Restore → build → test → Cobertura coverage → PR comment → enforce branch-coverage threshold |
| [`release-nuget.yml`](.github/workflows/release-nuget.yml) | Runs `ci-build-test` + CodeQL in parallel, then packs, generates an SBOM, pushes to GitHub Packages, and creates a GitHub Release |
| [`release-container.yml`](.github/workflows/release-container.yml) | Runs `ci-build-test` + CodeQL in parallel, then publishes migrations/web/worker images to GHCR with Trivy SBOM scans and creates a GitHub Release |
| [`update-bifrost.yml`](.github/workflows/update-bifrost.yml) | Stamps the calling realm's new SHA into Bifrost's submodule pointer; requires the `bifrost_token` secret |
| [`sound-gjallarhorn.yml`](.github/workflows/sound-gjallarhorn.yml) | Bumps `<{Realm}Version>` in Yggdrasil's `Directory.Packages.props` after a realm release; skips pre-releases |
| [`scatter-the-runes.yml`](.github/workflows/scatter-the-runes.yml) | Triggered by pushes to `config/**` — fans updated config to all realms via `scatter-the-runes.ps1` |

Call any `workflow_call` workflow from a realm with:

```yaml
jobs:
  ci:
    uses: NorseArchitecture/.github/.github/workflows/ci-build-test.yml@master
    with:
      minimum_coverage: 80   # optional; org floor is 0.1% (temporarily lowered until
                              # the ASP.NET Identity template is out of Yggdrasil)
```

## Soundtrack: Fall Through Ginnungagap
[![Soundtrack: Fall Through Ginnungagap](https://img.youtube.com/vi/hwAy58j1LaQ/maxresdefault.jpg)](https://www.youtube.com/watch?v=hwAy58j1LaQ)
