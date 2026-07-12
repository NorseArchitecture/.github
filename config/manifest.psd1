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
		# that ship and consume NuGet packages across the platform.
		nuget       = @(
			'src/Directory.Build.props'
			'src/Directory.Build.targets'
			'tests/Directory.Build.targets'
			'.github/workflows/release.yml'
		)
		# Test project MSBuild props — repos with a .NET build and tests
		tests       = @(
			'tests/Directory.Build.props'
		)
		# CI workflows — all realms including Bifrost
		ci          = @(
			'.github/workflows/auto-approve.yml'
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
	DefaultGroups   = @('universal', 'sdk', 'dotnet', 'nuget', 'tests', 'ci', 'workflows', 'claude')
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
		# Design system — token pipeline only (JS/Style Dictionary, @norsearchitecture/design-tokens).
		# npm-only, no .NET at all as of 2026-07-12 — DesignSystem.Stories split out to Bragi the
		# same day it landed here. No 'sdk'/'dotnet'/'nuget'/'tests' groups: nothing here restores a
		# .NET SDK or resolves NorseRef. ci.yml (hand-authored, not scattered) already calls
		# ci-build-test-npm.yml, not the dotnet gate. Ungated.
		Naglfar   = @{
			Groups = @('universal', 'ci', 'workflows', 'claude')
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
