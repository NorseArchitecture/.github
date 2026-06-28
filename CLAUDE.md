# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This repository is **Ginnungagap** — the primordial void from which all realms emerged. GitHub enforces the name `.github`; the lore name is Ginnungagap. It supplies `profile/README.md` (the org's public profile page) and the default community-health files — `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md` — that apply to every repo in the org that doesn't override them. It also hosts the reusable GitHub Actions workflows, the config scatter system, and `scripts/carve-the-laws.ps1`, the `gh`-CLI automation that carves the Law of the Æsir across the org's repos. Treat this repo as docs-plus-automation, not a service.

## Commands

There is no build/lint/test pipeline in this repo (no CI workflows, no `.editorconfig`). Operational commands:

### Org secrets

**`BIFROST_TOKEN`** — fine-grained PAT scoped to `NorseArchitecture/Bifrost` with `Contents: write`. Used by the `update-bifrost.yml` reusable workflow so realm pushes to `master` automatically advance Bifrost's submodule pointer. Set (or renew) with:

```bash
gh secret set BIFROST_TOKEN --org NorseArchitecture --visibility all --body "<token>"
```

Generate the replacement token at **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**: resource owner `NorseArchitecture`, repository `Bifrost`, permission `Contents: write`. Token was first set 2026-06-26 with a 366-day expiry — renewal due ~2027-06-27.

### Branch ruleset

The only other operational command is the ruleset script:

```powershell
./scripts/carve-the-laws.ps1            # apply "Law of the Æsir" to every repo in $AllRepos
./scripts/carve-the-laws.ps1 Asgard     # apply to a single repo
```

Requires `gh` authenticated with admin on the target repos. It is idempotent (PUT if a same-named ruleset exists, POST otherwise). Verify a change with:

```bash
gh ruleset list -R NorseArchitecture/<repo>
```

When adding a newly-born repo to the org, add it to `$GatedRepos` or `$UngatedRepos` in that script (currently gated: Asgard, Svartalfheim, Midgard, Yggdrasil, Urdarbrunnr, Ratatoskr, Heimdall, Himinbjorg; currently ungated: Bifrost, Naglfar, Glitnir, `.github` / Ginnungagap).

## Architecture: the cosmos

`profile/README.md` is the canonical map of the whole organization, not just this repo — read it before touching any Norse Architecture repo. The mapping is strict: **mythology markets, functions operate, docs explain** — repo names are Norse lore, namespaces (`Norse.Abstractions.*`, `Norse.Primitives.*`, etc.) are literal operational truth, and nothing else is allowed to drift between the two.

Dependency order (each layer rides only on the ones above it):

1. **Asgard** — `Norse.Abstractions.*`: contracts only, no implementations.
2. **Svartalfheim** — `Norse.Primitives.*`: value types, identifiers, result parsing, encryption.
3. **Urdarbrunnr** — `Norse.EntityFramework.*`: EF Core foundations (entity base types, DbContext, conventions, value converters, migrations chassis).
4. **Midgard** — `Norse.Infrastructure.*`: concrete implementations of Asgard's contracts (persistence, caching, external integrations).
5. **Ratatoskr** — `Norse.NServiceBus.*`: NServiceBus endpoint configuration, saga infrastructure, message conventions, and transport wiring.
6. **Yggdrasil** — `Norse.Hosting.*`: web/worker/migration service chassis.
7. **Himinbjörg** — `Norse.Identity.*`: backend-only EF persistence for ASP.NET Identity/OpenIddict — never crosses to WASM or MAUI.
8. **Heimdall** — `Norse.Access.*`: auth services on top of Himinbjörg, uniform across Blazor Server/WASM/MAUI.
9. **Bifröst** — `Norse.Orchestration.*`: .NET Aspire composition layer wiring services, databases, queues, config into a running platform.
10. **Naglfar** — `Norse.DesignSystem.*`: design tokens, spacing scale, radii, typography, and component primitives. Standalone — no substrate dependencies. Purpose-built to be superseded when the product vision is realized.
11. **Glitnir** — the design court: specs, plans, and proof-of-concept verdicts. Specs are argued to convergence here *before* any of the above renders code.

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
