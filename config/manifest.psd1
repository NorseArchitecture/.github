# manifest.psd1 — Platform config sync manifest
#
# Groups define collections of files; Realms list which groups they receive.
# Files are deduplicated across groups — a realm assigned 'universal' does not
# also need 'git' (universal already contains those files).
#
# Reserved slots (uncomment when UseProjectReferences feature lands):
#   nuget: 'src/Directory.Build.targets' and 'tests/Directory.Build.targets'
#   Place the canonical .targets files at config/src/ and config/tests/ first.
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
		)
		# Root MSBuild props — repos with a .NET build but not shipping to NuGet
		dotnet    = @(
			'Directory.Build.props'
		)
		# NuGet packaging props — repos that ship NuGet packages
		nuget     = @(
			'src/Directory.Build.props'
			'tests/Directory.Build.props'
			'src/Directory.Build.targets'
			'tests/Directory.Build.targets'
		)
	}
	Realms = @{
		# NuGet-shipping platform realms
		Svartalfheim = @('universal', 'dotnet', 'nuget')
		Asgard       = @('universal', 'dotnet', 'nuget')
		Midgard      = @('universal', 'dotnet', 'nuget')
		Urdarbrunnr  = @('universal', 'dotnet', 'nuget')
		Ratatoskr    = @('universal', 'dotnet', 'nuget')
		Heimdall     = @('universal', 'dotnet', 'nuget')
		Himinbjorg   = @('universal', 'dotnet', 'nuget')
		# Runtime host — universal + dotnet; owns its own src/ and tests/ props
		# (no IsAotCompatible=true, uses CPM — incompatible with nuget group files)
		Yggdrasil    = @('universal', 'dotnet')
		# Aspire composition root — universal only; owns its own minimal host props
		Bifrost      = @('universal')
		# Design system — no .NET tooling; crafts its own .editorconfig
		Naglfar      = @('git')
		# Docs and proofs of concept — git hygiene only
		Glitnir      = @('git')
	}
}
