# manifest.psd1 — Platform config sync manifest
#
# Groups define collections of files. Realm classification is by exception:
# any repo in the NorseArchitecture org not listed in Exceptions is a default
# realm — full NuGet-shipping group set, gated CI. Files are deduplicated
# across groups — a realm assigned 'universal' does not also need 'git'
# (universal already contains those files).

@{
	Groups = @{
		# Git hygiene only — repos without a .NET build
		git         = @(
			'.gitattributes'
			'.gitignore'
		)
		# Full .NET platform baseline
		universal   = @(
			'.editorconfig'
			'.gitattributes'
			'.gitignore'
			'LICENSE'
			'nuget.config'
		)
		# Shared SDK pin — separate from 'universal' so a realm can own its
		# own global.json (e.g. Bifrost layers a local msbuild-sdks entry)
		sdk         = @(
			'global.json'
		)
		# Root MSBuild props — repos with a .NET build but not shipping to NuGet
		dotnet      = @(
			'Directory.Build.props'
		)
		# NuGet packaging props — repos that ship NuGet packages. tests/Directory.Build.targets
		# lives here too (not in 'tests' below): same audience as src/Directory.Build.targets for
		# the same reason — both exist solely to resolve NorseRef (and now the generator-analyzer
		# strip target) via Bifrost's root Directory.Build.targets, which only matters for realms
		# that ship and consume NuGet packages across the platform. The canonical release.yml
		# itself lives in the separate 'release' group below, not here — see that group's comment.
		nuget       = @(
			'src/Directory.Build.props'
			'src/Directory.Build.targets'
			'tests/Directory.Build.targets'
		)
		# Test project MSBuild props — repos with a .NET build and tests
		tests       = @(
			'tests/Directory.Build.props'
		)
		# CI workflows — all realms including Bifrost
		ci          = @(
			'.github/workflows/auto-approve.yml'
		)
		# The canonical single-target (NuGet-only) release workflow — split out of 'nuget' above
		# 2026-07-12 so a realm can keep every other NuGet-packaging file scattered normally while
		# opting out of just this one. Naglfar is the first case: it dual-publishes npm and NuGet
		# from one release.yml (a version-sync gate plus two parallel publish jobs), which the
		# canonical single-target template would silently clobber on the next scatter run.
		release     = @(
			'.github/workflows/release.yml'
		)
		# Platform workflows — all realms except Bifrost (update-bifrost must not run in Bifrost)
		workflows   = @(
			'.github/workflows/update-bifrost.yml'
		)
		# Claude Code submodule guard — every realm except Bifrost (the valid session
		# root, which owns its own permissions+deny .claude/settings.json by hand) and
		# .github (source, already covered by ScatterExcludes). Blocks a session started
		# inside the submodule and redirects to Bifrost — see CLAUDE.md §1.
		claude      = @(
			'.claude/settings.json'
		)
	}
	# Default group set for any repo not named in Exceptions below.
	DefaultGroups   = @('universal', 'sdk', 'dotnet', 'nuget', 'release', 'tests', 'ci', 'workflows', 'claude')
	# Repos scatter must never sync into — source of the config, not a consumer.
	ScatterExcludes = @('.github')
	# Anything NOT listed here is a default realm: ships to NuGet, full group
	# set, gated CI. Exception entries declare only the fields that differ
	# from default — an absent field falls back to DefaultGroups / Gated=$true.
	Exceptions      = @{
		# Runtime host — universal + dotnet + tests (props only, no 'nuget'); owns its own
		# src/Directory.Build.targets and tests/Directory.Build.targets (no IsAotCompatible=true,
		# uses CPM — incompatible with 'nuget' group files. See
		# ../Bifrost/Glitnir/docs/Platform/specs/2026-07-01-norseref-generator-forwarding-design.md)
		Yggdrasil = @{
			Groups = @('universal', 'sdk', 'dotnet', 'tests', 'ci', 'workflows', 'claude')
		}
		# Aspire composition root — universal only; owns its own global.json
		# (local msbuild-sdks entry for Microsoft.Build.NoTargets, used by Glitnir's
		# doc-glob project since Glitnir has no global.json of its own). Ungated —
		# no gate / build CI check exists for an Aspire AppHost. No 'claude' group —
		# Bifrost is the valid session root and hand-owns its own permissions+deny
		# .claude/settings.json, not the submodule guard hook.
		Bifrost   = @{
			Groups = @('universal', 'ci')
			Gated  = $false
		}
		# Design system — token pipeline (JS/Style Dictionary) plus DesignSystem.Tokens, a single
		# 100%-generated .NET package (FluentTokenSeed.g.cs + norse-design-tokens.css) packed
		# alongside @norsearchitecture/design-tokens in the same release step. "npm-only, no .NET"
		# narrows to "no hand-authored C#" as of 2026-07-12 (Theme Selection Machinery addendum,
		# ../Bifrost/Glitnir/docs/Platform/specs/2026-07-11-blazor-component-architecture-design.md).
		# No 'release' group: Naglfar's release.yml dual-publishes npm and NuGet from one file
		# (a version-sync gate plus two parallel publish jobs) — permanently bespoke, not the
		# canonical single-target template every other 'nuget'-shipping realm scatters unmodified.
		# Ungated for now — real dotnet-test coverage exists as of 2026-07-12
		# (tests/DesignSystem.Tokens.Tests), unlike when this was first written; revisit Gated.
		Naglfar   = @{
			Groups = @('universal', 'sdk', 'dotnet', 'nuget', 'tests', 'ci', 'workflows', 'claude')
			Gated  = $false
		}
		# Design system — story content only: DesignSystem.Stories, a content-only Razor Class
		# Library (.stories.razor, .NET, consumes Abstractions.Components et al. via NorseRef).
		# Split out of Naglfar 2026-07-12 — see ../Bifrost/Glitnir/docs/Platform/specs/2026-07-12-
		# designsystem-stories-hosting-design.md (addendum records the split). Ungated: little
		# unit-testable logic lives in this repo directly — Asgard's components are already gated
		# in their own repo. Revisit if that changes.
		Bragi     = @{
			Groups = @('universal', 'sdk', 'dotnet', 'nuget', 'tests', 'ci', 'workflows', 'claude')
			Gated  = $false
		}
		# Docs and proofs of concept — git hygiene only. Ungated.
		Glitnir   = @{
			Groups = @('git', 'ci', 'workflows', 'claude')
			Gated  = $false
		}
		# Source of the canonical config — scatter excludes it outright (see
		# ScatterExcludes above); only its Gated classification is relevant here.
		'.github' = @{
			Gated = $false
		}
	}
}
