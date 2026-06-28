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
		)
		# Test project MSBuild props — repos with a .NET build and tests
		tests     = @(
			'tests/Directory.Build.props'
			'tests/Directory.Build.targets'
		)
	}
	Realms = @{
		# NuGet-shipping platform realms
		Svartalfheim = @('universal', 'dotnet', 'nuget', 'tests')
		Asgard       = @('universal', 'dotnet', 'nuget', 'tests')
		Midgard      = @('universal', 'dotnet', 'nuget', 'tests')
		Urdarbrunnr  = @('universal', 'dotnet', 'nuget', 'tests')
		Ratatoskr    = @('universal', 'dotnet', 'nuget', 'tests')
		Heimdall     = @('universal', 'dotnet', 'nuget', 'tests')
		Himinbjorg   = @('universal', 'dotnet', 'nuget', 'tests')
		# Runtime host — universal + dotnet + tests; owns its own src/ props
		# (no IsAotCompatible=true, uses CPM — incompatible with nuget group files)
		Yggdrasil    = @('universal', 'dotnet', 'tests')
		# Aspire composition root — universal only; owns its own minimal host props
		Bifrost      = @('universal')
		# Design system — no .NET tooling; crafts its own .editorconfig
		Naglfar      = @('git')
		# Docs and proofs of concept — git hygiene only
		Glitnir      = @('git')
	}
}
