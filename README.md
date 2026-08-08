# Ginnungagap

> The primordial void from which all realms emerged. GitHub enforces the repository name `.github`; the lore name is Ginnungagap.

<p align="center">
  <img src="https://github.com/user-attachments/assets/aad75315-256a-4103-815c-7534b5b0c22d" alt="Ginnungagap — the primordial void before all creation, where the ice of Niflheim and the fire of Muspelheim met and breathed the nine realms into being" title="Ginnungagap — the void before creation, the source of all realms" />
</p>

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

`config/` is the single source of truth for platform-wide config — `.editorconfig`, `.gitattributes`, `.gitignore`, `global.json`, `nuget.config`, `LICENSE`, MSBuild props, and CI workflows. `config/manifest.psd1` assigns each realm one or more named file groups: `git`, `universal`, `sdk`, `dotnet`, `nuget`, `tests`, `schema`, `ci`, `release`, `workflows`, `claude`. `schema` is the odd one out — it's assigned to no realm by default; a repo opts in via a `manifest.psd1` `Exceptions` entry the day it grows a `{Realm}/schema/{Name}.Database` Microsoft.Build.Sql project. See "Schema projects" below.

Any push to `config/**` on `master` triggers `scatter-the-runes.yml`, which runs `scatter-the-runes.ps1`. The script clones each realm, copies its assigned files, and opens an auto-merge PR — or pushes onto an existing sync branch if one is already open. Idempotent and safe to re-run manually:

```powershell
pwsh scripts/scatter-the-runes.ps1                                    # all realms
pwsh scripts/scatter-the-runes.ps1 Svartalfheim                       # one realm
pwsh scripts/scatter-the-runes.ps1 -Realms Asgard,Svartalfheim,Midgard  # selected realms
pwsh scripts/scatter-the-runes.ps1 -DryRun                            # print plan, no writes
pwsh scripts/scatter-the-runes.ps1 -Audit                             # classify every destination, write nothing
```

Requires `SCATTER_PAT` — a PAT with `repo` scope set as an org secret. Locally: `gh auth login` or `$env:GH_TOKEN`.

Before touching any file, the script classifies the realm's existing copy against the canonical file's git lineage (`Get-RuneClassification`, `scripts/lib/rune-lineage.ps1`) into one of four states: `Current` (byte-identical to `HEAD`), `Stale` (matches some earlier canonical blob — an ordinary not-yet-synced file, including one the realm never had), `Divergent` (content outside the canonical file's lineage entirely — a realm edited a file it isn't allowed to own), or `LineageUnavailable` (no git history for the canonical path, or this checkout of Ginnungagap is a shallow clone — full history is required, hence `fetch-depth: 0` on the `scatter-the-runes.yml` checkout step). `-Audit` runs the classification and prints a report for every realm/file pair without copying, committing, or pushing anything. Outside audit mode, `LineageUnavailable` is an unconditional hard-fail (the script refuses to guess), and `Divergent` is also a hard-fail unless the specific `Realm/path` is named via `-AcceptDivergence` for a deliberate, explicit reversion — scattering back over a realm's own edits should never be an accident.

**Canonicity law:** a scattered file is canonical by definition — no realm ever edits one directly. Realm-specific law instead lives in one of two realm-owned files that are never scattered: `Directory.Analyzers.props` (a realm's manifest of the `NorseRealmAnalyzer` items it ships — its own Roslyn diagnostics analyzers) and `Directory.Realm.targets` (an additive-only seam for realm-specific targets; it may add new items and targets but must never redefine a canonical property or target). Both are imported at the very end of the realm-root `Directory.Build.targets` — see below.

## Realm-root `Directory.Build.targets`

`config/Directory.Build.targets` (the `dotnet` group) is the single home of law shared across every layer — `src/`, `tests/`, `gen/`, and now `schema/` — so the group-level `Directory.Build.targets` files stay thin chain stubs plus whatever is genuinely specific to that one layer (e.g. `tests/`'s `OutputType=Exe`). It carries, in order: the SDK-implicit-using removal and analyzer-package delivery `Choose` (both already present before this round); the standalone `NorseRef`/`NorseDesignRef` fallback (hoisted 2026-08-07 from the `src`/`tests`/`gen` group files — keyed on Bifröst's *absence*, never on `UseProjectReferences`, so the workspace's own crossing in Bifröst's root file never double-emits); the standalone realm-analyzer-manifest attach (imports the realm's own `Directory.Analyzers.props` and wires its declared analyzers in as a realm-internal `ProjectReference`, guarded twice over so the workspace path — Bifröst's own manifest-driven attach — is never double-imported); the hoisted generator-strip target `_NorseRemoveUnwantedGeneratorAnalyzers` (now covering `gen/` too, closing a gap the Task 7 postmortem flagged — previously only `src/`/`tests/` stripped stray NuGet-delivered generator copies); and, imported last so realm additions can react to canonical state without mutating it, the `Directory.Realm.targets` seam.

## Schema projects

The `schema` scatter group (`config/schema/Directory.Build.props` + `.targets`) exists for consumer platforms bridging to Microsoft.Build.Sql (DacFx) schema projects — the platform's own persistence stays EF Core + Postgres. It ships at props level: native `DSP`/`ModelCollation`, brand-injected `PackageId`/`SqlTargetName`, and `TreatTSqlWarningsAsErrors` for T-SQL compiler warnings (a separate concern from DacFx static-analysis rule promotion). At targets level it defaults `RunSqlCodeAnalysis=true` under `UseProjectReferences=true` — closing a gap where a rules package's packed `build/*.targets` (the actual mechanism that enables analysis and promotes rule IDs to errors) only auto-imports across a NuGet package crossing, never through a `ProjectReference`; a documented (commented) rule-promotion extension-point pattern for a consumer's own rules package; and a stale-transitive-rule strip target mirroring the Roslyn generator strip's provenance doctrine (only a packed copy of a `Rules="true"` `NorseRef` is stripped — the live `ProjectReference` copy always wins).

`scripts/verify-schema-templates.ps1` proves the whole thing end to end against a disposable fixture realm (`scripts/verify-schema-fixtures/`): both crossings (`ProjectReference` and package), `RunSqlCodeAnalysis` auto-enable, rule promotion (a fixture table literally named `forbidden` trips a fixture DacFx rule, `NR0001`, promoted to a hard build error only when the promotion line is active), and the stale-transitive-rule strip. Run it after touching anything under `config/schema/`.

## Reusable workflows

A tag push (`v*.*.*`) is the sole release inception point. Each realm's own `release.yml` runs `build-test` + one `codeql` call per language it has, gates one or more `publish-*` jobs on those, then fans in to a single `create-release` job — so a realm shipping to more than one target (e.g. Naglfar's npm + NuGet) never races two jobs both trying to create the same GitHub Release. `publish-*` workflows are publish-only: they pack/push/scan and upload their output as an artifact bundle named `<target>-artifacts`; `create-release.yml` downloads every bundle matching that pattern and creates the release in one shot, whatever the bundle count.

| Workflow | Purpose |
|----------|---------|
| [`ci-build-test.yml`](.github/workflows/ci-build-test.yml) | Restore → build → test → Cobertura coverage → PR comment → enforce branch-coverage threshold |
| [`ci-build-test-npm.yml`](.github/workflows/ci-build-test-npm.yml) | Checkout → Node setup → install → build → test — the npm-realm equivalent of `ci-build-test.yml` |
| [`codeql.yml`](.github/workflows/codeql.yml) | Language-parameterized CodeQL scan (`csharp` or `javascript-typescript`); a realm calls it once per language it actually has |
| [`publish-nuget.yml`](.github/workflows/publish-nuget.yml) | Packs, generates an SBOM, pushes to GitHub Packages, uploads `nuget-artifacts` — publish-only, no release creation |
| [`publish-npm.yml`](.github/workflows/publish-npm.yml) | Packs, generates an SBOM, publishes to GitHub Packages, uploads `npm-artifacts` — publish-only, no release creation |
| [`publish-container.yml`](.github/workflows/publish-container.yml) | Builds, Trivy-scans, and pushes all four Yggdrasil images to GHCR in parallel (matrix), uploads `container-<name>-artifacts` — publish-only, no release creation |
| [`create-release.yml`](.github/workflows/create-release.yml) | Downloads every `*-artifacts` bundle a realm's publish jobs produced and creates exactly one GitHub Release |
| [`update-bifrost.yml`](.github/workflows/update-bifrost.yml) | Stamps the calling realm's new SHA into Bifröst's submodule pointer; requires the `bifrost_token` secret |
| [`sound-gjallarhorn.yml`](.github/workflows/sound-gjallarhorn.yml) | Bumps `<{Realm}Version>` in Yggdrasil's `Directory.Packages.props` once a realm's NuGet package is live; skips pre-releases |
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
