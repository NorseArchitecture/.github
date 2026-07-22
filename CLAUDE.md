# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This repository is **Ginnungagap** — the primordial void from which all realms emerged. GitHub enforces the name `.github`; the lore name is Ginnungagap. It supplies `profile/README.md` (the org's public profile page) and the default community-health files — `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md` — that apply to every repo in the org that doesn't override them. It also hosts the reusable GitHub Actions workflows, the config scatter system, and `scripts/carve-the-laws.ps1`, the `gh`-CLI automation that carves the Law of the Æsir across the org's repos. Treat this repo as docs-plus-automation, not a service.

## Commands

There is no build/lint/test pipeline *for this repo's own content* — no `.editorconfig` at the root, no C# to compile. Most files under `.github/workflows/` are `workflow_call`-only definitions consumed by other realms; the one exception is `scatter-the-runes.yml`, which does trigger on pushes to `config/**` here (see Config scatter below). Operational commands:

### Org secrets

**`BIFROST_TOKEN`** — fine-grained PAT scoped to `NorseArchitecture/Bifrost` with `Contents: write`. Used by the `update-bifrost.yml` reusable workflow so realm pushes to `master` automatically advance Bifröst's submodule pointer. Set (or renew) with:

```bash
gh secret set BIFROST_TOKEN --org NorseArchitecture --visibility all --body "<token>"
```

Generate the replacement token at **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**: resource owner `NorseArchitecture`, repository `Bifrost`, permission `Contents: write`. Token was first set 2026-06-26 with a 366-day expiry — renewal due ~2027-06-27.

**`SCATTER_PAT`** — classic PAT with `repo` scope, set as an org secret. Used by `scatter-the-runes.yml` (fans `config/**` out to every realm) and `sound-gjallarhorn.yml` (cross-repo checkout of this repo's scripts plus a push/PR against Yggdrasil). Set with:

```bash
gh secret set SCATTER_PAT --org NorseArchitecture --visibility all --body "<token>"
```

### Branch ruleset

```powershell
./scripts/carve-the-laws.ps1            # apply "Law of the Æsir" to every repo in $AllRepos
./scripts/carve-the-laws.ps1 Asgard     # apply to a single repo
```

Requires `gh` authenticated with admin on the target repos. It is idempotent (PUT if a same-named ruleset exists, POST otherwise). Verify a change with:

```bash
gh ruleset list -R NorseArchitecture/<repo>
```

Repo discovery and gate classification are both dynamic (`gh repo list` plus `Get-RealmGated` in `scripts/lib/realm-classification.ps1`, reading the same `config/manifest.psd1` that drives scatter) — onboarding a new **default (gated)** realm needs no script edit at all. A realm only needs a `manifest.psd1` `Exceptions` entry when it isn't gated or doesn't take the default scatter group set (currently ungated: Bifröst, Naglfar, Bragi, Glitnir, `.github` / Ginnungagap; everything else discovered in the org is gated).

### Config scatter

`config/` (with `config/manifest.psd1` declaring which file groups each realm receives) is the source of truth for platform-wide config — `.editorconfig`, `.gitattributes`, `.gitignore`, `global.json`, `nuget.config`, `LICENSE`, MSBuild props, and the realm-facing `release.yml`. A push to `config/**` on `master` triggers `scatter-the-runes.yml` automatically; it can also be run by hand:

```powershell
./scripts/scatter-the-runes.ps1                                    # all realms
./scripts/scatter-the-runes.ps1 Svartalfheim                       # one realm
./scripts/scatter-the-runes.ps1 -DryRun                            # print plan, no writes
```

Idempotent — clones each realm, copies its assigned files, and opens (or updates) an auto-merge PR. Requires `SCATTER_PAT`; locally, `gh auth login` or `$env:GH_TOKEN` substitutes for it.

`scripts/sound-gjallarhorn.ps1` (renamed from `phone-home-nuget.ps1` on 2026-06-30 — check any older notes for the stale name) is the other scatter-adjacent script: it bumps `<{Realm}Version>` in Yggdrasil's `Directory.Packages.props` after a realm's tagged release and opens an auto-merge PR there. It's invoked by `sound-gjallarhorn.yml`, not run by hand.

## Architecture: the cosmos

`profile/README.md` is the canonical map of the whole organization, not just this repo — read it before touching any Norse Architecture repo. The mapping is strict: **mythology markets, functions operate, docs explain** — repo names are Norse lore, namespaces (`Norse.Abstractions.*`, `Norse.Primitives.*`, etc.) are literal operational truth, and nothing else is allowed to drift between the two.

Dependency order (each layer rides only on the ones above it):

1. **Asgard** — `Norse.Abstractions.*`: contracts only, no implementations.
2. **Svartálfheim** — `Norse.Primitives.*`: value types, identifiers, result parsing, encryption.
3. **Urðarbrunnr** — `Norse.EntityFramework.*`: EF Core foundations (entity base types, DbContext, conventions, value converters, migrations chassis).
4. **Midgard** — `Norse.Infrastructure.*`: concrete implementations of Asgard's contracts (persistence, caching, external integrations).
5. **Ratatoskr** — `Norse.NServiceBus.*`: NServiceBus endpoint configuration, saga infrastructure, message conventions, and transport wiring.
6. **Yggdrasil** — `Norse.Hosting.*`: web/worker/migration service chassis.
7. **Himinbjörg** — `Norse.Identity.*`: backend-only EF persistence for ASP.NET Identity/OpenIddict — never crosses to WASM or MAUI.
8. **Heimdall** — `Norse.AuthN.*`: the authn story on top of Himinbjörg — login, register, forgot-password, 2FA setup, recovery, and reset — uniform across Blazor Server/WASM/MAUI.
9. **Bifröst** — `Norse.Orchestration.*`: .NET Aspire composition layer wiring services, databases, queues, config into a running platform.
10. **Naglfar** — `Norse.DesignSystem.*`: the token pipeline (design tokens, spacing scale, radii, typography). npm-only, no .NET. Standalone — no substrate dependencies. Purpose-built to be superseded when the product vision is realized.
11. **Bragi** — `Norse.DesignSystem.Stories`: content-only Razor Class Library of component story pages. Rides `NorseRef` on every realm that publishes Blazor components — Asgard's `Abstractions.Components` today, `AuthN.Components.FluentUI` (Heimdall) and `ReferenceData.Components.FluentUI` (Mímir) as each ships. Hosted at runtime by Yggdrasil's `Hosting.Stories.Client`/`.Server`. Split out of Naglfar 2026-07-12.
12. **Glitnir** — the design court: specs, plans, and proof-of-concept verdicts. Specs are argued to convergence here *before* any of the above renders code.

Consuming services live under their own root (`{Company}.{Context}.*`), conform to `Norse.Abstractions`, and own everything above the substrate — the platform deliberately knows nothing about their domain (see the "three Billing contexts, zero shared code" example in `profile/README.md` for why that gap is the design, not a gap to close).

Org-wide enforced opinions (apply when editing *any* Norse Architecture repo, including this one): compile-time over runtime (analyzers/source generators over reflection), fail loudly with no silent fallbacks, each component smart about exactly one thing, warnings-as-errors, and naming that names the role rather than the mechanism.

## Repo-specific conventions

- `.gitattributes` already normalizes line endings (LF everywhere except `.csv` per RFC 4180 and Windows `.bat`/`.cmd`); don't second-guess it. Note `.github/` itself is `export-ignore`d from archives.
- `*.Designer.cs`, `*.g.cs`, `*.g.i.cs`, `*ModelSnapshot.cs` are `linguist-generated`. EF migration bodies (`*Migration.cs`) are deliberately **not** marked generated — migration diffs are review surface, not noise to collapse.
- Markdown in this repo is voiced in-world (Norse lore framing) for `profile/README.md` and this repo's own `README.md`; the community-health files (`CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`) are plain operational tone since they're read by external contributors, not just the org's own engineers. Match the register of the file you're editing.
- Per-repo `CONTRIBUTING.md`/`SECURITY.md` override these defaults when they exist — don't assume the files here are the last word for any other repo without checking.

## Working in this repo (and across Norse Architecture generally)

This org is built spec-first, plan-second, code-last — `profile/README.md`'s own "Status" and "The crooked path" sections describe Glitnir's design-court process; that is not marketing copy, it is the actual required workflow. The `superpowers` plugin is enabled for this repo specifically so that workflow has teeth instead of being aspirational text:

- Treat **brainstorming** as mandatory before any plan — design questions get argued to convergence (Glitnir's role) before a plan exists.
- Once a design has converged, use **writing-plans**, then **executing-plans** — don't jump straight from idea to diff.
- Implementation work proceeds **test-driven** (red/green/refactor), and non-trivial multi-step execution should be delegated via **subagent-driven-development** / **dispatching-parallel-agents** rather than done monolithically inline.
- Before declaring anything done, run **verification-before-completion**; route real changes through **requesting-code-review** / **receiving-code-review**; close out with **finishing-a-development-branch**.
- Bugs are the one exception to spec-first: go straight to **systematic-debugging**, no design phase required.

This repo itself has nothing to TDD (no test runner exists), but the script and docs here still go through brainstorm → plan → execute → verify like everything else in the org — and any new automation added here (CI workflows, additional scripts) should arrive with tests from the start rather than retrofitted.
