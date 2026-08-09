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
		# Full .NET platform baseline. {Realm}.sln.DotSettings is the team-shared ReSharper
		# layer: the "Norse Cleanup" profile (usings tasks OFF — R#'s resolver is degraded
		# on .NET 11 preview and strips live usings; IDE0005-as-error owns using hygiene
		# instead) plus silent-cleanup default. The {Realm} token in the filename is
		# replaced with the repo name at scatter time (R# requires
		# {SolutionName}.sln.DotSettings, and every realm's solution is named for the
		# repo). Proven in Asgard's trial by fire 2026-08-07 alongside the .editorconfig
		# ReSharper block. Rides here (2026-08-08, moved out of 'dotnet') rather than its
		# own group — every current 'universal' member already has a .sln/.slnx and is a
		# sensible R# target; Glitnir/Vafthrudnir aren't in 'universal' at all, so they
		# were never at risk of receiving it either way.
		universal   = @(
			'.editorconfig'
			'.gitattributes'
			'.gitignore'
			'LICENSE'
			'nuget.config'
			'{Realm}.sln.DotSettings'
		)
		# Shared SDK pin — separate from 'universal' so a realm can own its
		# own global.json (e.g. Bifrost layers a local msbuild-sdks entry)
		sdk         = @(
			'global.json'
		)
		# Root MSBuild props+targets — merged 2026-08-08 (the former separate 'dotnet'
		# group shrank to just Directory.Build.props once {Realm}.sln.DotSettings moved to
		# 'universal', so two single-purpose groups added ceremony without adding
		# precision). Targets-time law — the SDK-implicit-using removal and the analyzer
		# delivery Choose — MUST evaluate after Directory.Packages.props so CPM's property
		# is visible (props-level delivery misfires NU1008 under CPM, proven live). One
		# group so a realm opts out of both files together, or neither. Svartálfheim and
		# Naglfar are the only current exceptions: permanent architectural leaves (never
		# declare a NorseRef/NorseDesignRef/NorseGeneratorRef, by design, not by current
		# absence) — both hand-own a lean Directory.Build.props; Svartálfheim also
		# hand-owns a lean Directory.Build.targets, Naglfar has none at all. the-runes.md
		# ch. 2/7.
		msbuild     = @(
			'Directory.Build.props'
			'Directory.Build.targets'
		)
		# NuGet packaging props — repos that ship NuGet packages. tests/Directory.Build.targets
		# lives here too (not in 'tests' below): same audience as src/Directory.Build.targets for
		# the same reason — both exist solely to resolve NorseRef (and now the generator-analyzer
		# strip target) via Bifrost's root Directory.Build.targets, which only matters for realms
		# that ship and consume NuGet packages across the platform. The canonical release.yml
		# itself lives in the separate 'release' group below, not here — see that group's comment.
		# gen/Directory.Build.props is the canonical Roslyn-generator scaffold (netstandard2.0,
		# IsRoslynComponent, IsPackable=false, etc. — see Urdarbrunnr's copy for the pattern this
		# was hoisted from). It scatters as an otherwise-empty gen/ folder into every nuget realm
		# that has no generator today; the moment one lands, the bootstrap is already sitting there.
		# gen/Directory.Build.targets closes a gap found 2026-07-26: gen/ had no NorseRef-resolution
		# targets file of its own, so a generator project declaring NorseRef (Urdarbrunnr's first
		# case, adopting Asgard's Abstractions.Emit) silently got no reference at all outside
		# Bifrost — MSBuild's implicit walk-up found nothing between gen/ and Bifrost's own root
		# Directory.Build.targets, and standalone/CI builds (UseProjectReferences=false) never hit
		# that root file. Same import-or-fallback shape as src/Directory.Build.targets, minus the
		# analyzer-strip target and NorseDesignRef (neither applies to a generator project today).
		nuget       = @(
			'src/Directory.Build.props'
			'src/Directory.Build.targets'
			'tests/Directory.Build.targets'
			'gen/Directory.Build.props'
			'gen/Directory.Build.targets'
		)
		# Test project MSBuild props — repos with a .NET build and tests
		tests       = @(
			'tests/Directory.Build.props'
		)
		# Microsoft.Build.Sql schema projects — assigned to NO realm by default; a repo opts in
		# via its Exceptions entry the day it grows a {Realm}/schema/{Name}.Database project.
		# The platform's own persistence remains EF Core + Postgres constraints (Key Rejections);
		# this group exists for consumer bridges that chose SQL Server. the-runes.md ch. 8.
		schema      = @(
			'schema/Directory.Build.props'
			'schema/Directory.Build.targets'
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
	DefaultGroups   = @('universal', 'sdk', 'msbuild', 'nuget', 'release', 'tests', 'ci', 'workflows', 'claude')
	# Repos scatter must never sync into. '.github' is the source of the config, not a
	# consumer. 'EFCore.NamingConventions' is a fork of a third-party library
	# (github.com/efcore/EFCore.NamingConventions, tracked as 'upstream') — not a platform
	# realm, and scattering our own conventions into it fights its ability to cleanly pull
	# and merge from upstream. Already found contaminated with .editorconfig/
	# Directory.Build.props/global.json from a prior scatter run; excluded 2026-08-08.
	ScatterExcludes = @('.github', 'EFCore.NamingConventions')
	# Anything NOT listed here is a default realm: ships to NuGet, full group
	# set, gated CI. Exception entries declare only the fields that differ
	# from default — an absent field falls back to DefaultGroups / Gated=$true.
	Exceptions      = @{
		# Runtime host — universal + dotnet + tests (props only, no 'nuget'); owns its own
		# src/Directory.Build.targets and tests/Directory.Build.targets by convention, not because
		# of a structural incompatibility — since the group-level shrink (2026-08-07) these files
		# are byte-identical to the canonical scattered 'nuget' group versions and CPM-safe.
		# Yggdrasil-owned and manually kept in sync with the canonical files; a candidate for a
		# future minor manifest simplification (folding it back into 'nuget') rather than a
		# permanent exception. See
		# ../Bifrost/Glitnir/docs/Platform/specs/2026-07-01-norseref-generator-forwarding-design.md)
		Yggdrasil   = @{
			Groups = @('universal', 'sdk', 'msbuild', 'tests', 'ci', 'workflows', 'claude')
		}
		# Aspire composition root — universal only; owns its own global.json
		# (local msbuild-sdks entry for Microsoft.Build.NoTargets, used by Glitnir's
		# doc-glob project since Glitnir has no global.json of its own). Ungated —
		# no gate / build CI check exists for an Aspire AppHost. No 'claude' group —
		# Bifrost is the valid session root and hand-owns its own permissions+deny
		# .claude/settings.json, not the submodule guard hook.
		Bifrost     = @{
			Groups = @('universal', 'ci')
			Gated  = $false
		}
		# The forge — Norse.Primitives, the platform's dependency-graph root. Permanent
		# architectural leaf: nothing sits below it, so it never declares a NorseRef/
		# NorseDesignRef/NorseGeneratorRef and never will (2026-08-08 ruling). Owns its own
		# realm-root Directory.Build.targets from here on — lean: chain import, the NORSE070
		# wire-format ban, and its own standalone-mode analyzer self-check (so its own
		# projects still get checked against Architecture.Analyzers/Primitives.Analyzers in
		# CI). The NorseRef fallback Choose, the Architecture.Analyzers package Choose, and
		# the generator-strip target are all dropped — none can ever fire here, and the
		# Architecture.Analyzers Choose was actively double-delivering the package alongside
		# this realm's own manifest ProjectReference. the-runes.md ch. 2/7.
		Svartalfheim = @{
			Groups = @('universal', 'sdk', 'nuget', 'release', 'tests', 'ci', 'workflows', 'claude')
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
		# Also excluded from 'msbuild' (2026-08-08, same ruling as Svartálfheim above, a
		# permanent architectural leaf) — but unlike Svartálfheim, Directory.Build.targets is
		# deleted outright here, not replaced: an RCL wrapping generated token CSS + a
		# generated C# file has no hand-authored surface for any analyzer to ever police,
		# so even the lean self-check has nothing to attach to. the-runes.md ch. 2/7.
		Naglfar     = @{
			Groups = @('universal', 'sdk', 'nuget', 'tests', 'ci', 'workflows', 'claude')
			Gated  = $false
		}
		# Design system — story content only: DesignSystem.Stories, a content-only Razor Class
		# Library (.stories.razor, .NET, consumes Abstractions.Components et al. via NorseRef).
		# Split out of Naglfar 2026-07-12 — see ../Bifrost/Glitnir/docs/Platform/specs/2026-07-12-
		# designsystem-stories-hosting-design.md (addendum records the split).
		#
		# Unlike Naglfar, Bragi ships plain NuGet only (no npm dual-publish) — it gets the
		# canonical 'release' group like any other single-target realm. It was carved out of
		# Naglfar's Exceptions entry the same day 'release' was split out of 'nuget' and the
		# omission rode along by copy-paste; without it scatter never overwrote whatever
		# release.yml Bragi was left with post-split, and it went stale (2026-07-15).
		#
		# Gated as of 2026-08-08 — no longer an exception, falls through to the default
		# (Gated=$true). Previously ungated on the theory that little unit-testable logic
		# lives here directly; flipped to require the gate / build check like every other
		# default realm.
		Bragi       = @{
			Groups = @('universal', 'sdk', 'msbuild', 'nuget', 'release', 'tests', 'ci', 'workflows', 'claude')
		}
		# Docs and proofs of concept — git hygiene only. Ungated.
		Glitnir     = @{
			Groups = @('git', 'ci', 'workflows', 'claude')
			Gated  = $false
		}
		# Bruno gRPC/REST/MCP collections — GUI-authored yml, no .NET build. Bruno's CLI can't
		# drive gRPC yet, and there's no integration server to bounce requests off of, so for now
		# this rides exactly like Glitnir: git hygiene only, ungated, still gets update-bifrost.yml
		# so a merge to master flows through the same submodule-bump path as every other realm.
		# Revisit once Bruno's gRPC support and an integration server both land.
		Vafthrudnir = @{
			Groups = @('git', 'ci', 'workflows', 'claude')
			Gated  = $false
		}
		# Source of the canonical config — scatter excludes it outright (see
		# ScatterExcludes above); only its Gated classification is relevant here.
		'.github'   = @{
			Gated = $false
		}
		# Third-party library fork — scatter excludes it outright (see ScatterExcludes
		# above); only its Gated classification is relevant here. Not a platform realm, so
		# none of our build-gate CI conventions apply — it carries its own upstream CI.
		'EFCore.NamingConventions' = @{
			Gated = $false
		}
	}
}
