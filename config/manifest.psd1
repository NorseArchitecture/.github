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
	}
	# Default group set for any repo not named in Exceptions below.
	DefaultGroups   = @('universal', 'sdk', 'dotnet', 'nuget', 'tests', 'ci', 'workflows')
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
			Groups = @('universal', 'sdk', 'dotnet', 'tests', 'ci', 'workflows')
		}
		# Aspire composition root — universal only; owns its own global.json
		# (local msbuild-sdks entry for Microsoft.Build.NoTargets, used by Glitnir's
		# doc-glob project since Glitnir has no global.json of its own). Ungated —
		# no gate / build CI check exists for an Aspire AppHost.
		Bifrost   = @{
			Groups = @('universal', 'ci')
			Gated  = $false
		}
		# Design system — no .NET tooling; crafts its own .editorconfig. Ungated.
		Naglfar   = @{
			Groups = @('git', 'ci', 'workflows')
			Gated  = $false
		}
		# Docs and proofs of concept — git hygiene only. Ungated.
		Glitnir   = @{
			Groups = @('git', 'ci', 'workflows')
			Gated  = $false
		}
		# Source of the canonical config — scatter excludes it outright (see
		# ScatterExcludes above); only its Gated classification is relevant here.
		'.github' = @{
			Gated = $false
		}
	}
}
