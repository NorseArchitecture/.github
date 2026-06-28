# manifest.psd1 — Platform config sync manifest
#
# Groups define collections of files; Realms list which groups they receive.
# Files are deduplicated across groups — a realm assigned 'universal' does not
# also need 'git' (universal already contains those files).

@{
	Groups = @{
		# Git hygiene only — repos without a .NET build
		git       = @(
			'.gitattributes'
			'.gitignore'
		)
		# Full .NET platform baseline
		universal = @(
			'.editorconfig'
			'.gitattributes'
			'.gitignore'
			'global.json'
			'LICENSE'
			'nuget.config'
		)
		# Root MSBuild props — repos with a .NET build but not shipping to NuGet
		dotnet    = @(
			'Directory.Build.props'
		)
		# NuGet packaging props — src-side only; repos that ship NuGet packages
		nuget     = @(
			'src/Directory.Build.props'
			'src/Directory.Build.targets'
			'.github/workflows/release.yml'
		)
		# Test project MSBuild props — repos with a .NET build and tests
		tests     = @(
			'tests/Directory.Build.props'
			'tests/Directory.Build.targets'
		)
		# Platform workflows — all realms except Bifrost (composition root manages its own)
		workflows = @(
			'.github/workflows/update-bifrost.yml'
		)
	}
	Realms = @{
		# NuGet-shipping platform realms
		Svartalfheim = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		Asgard       = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		Midgard      = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		Urdarbrunnr  = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		Ratatoskr    = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		Heimdall     = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		Himinbjorg   = @('universal', 'dotnet', 'nuget', 'tests', 'workflows')
		# Runtime host — universal + dotnet + tests; owns its own src/ props
		# (no IsAotCompatible=true, uses CPM — incompatible with nuget group files)
		Yggdrasil    = @('universal', 'dotnet', 'tests', 'workflows')
		# Aspire composition root — universal only; owns its own minimal host props
		Bifrost      = @('universal')
		# Design system — no .NET tooling; crafts its own .editorconfig
		Naglfar      = @('git', 'workflows')
		# Docs and proofs of concept — git hygiene only
		Glitnir      = @('git', 'workflows')
	}
}
